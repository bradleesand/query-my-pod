require "net/http"
require "json"

# Service for querying a local LLM (Ollama) with search results to generate cited responses.
# Takes search results from TranscriptSearchService and builds a prompt with context,
# then calls Ollama API to generate a natural language response with citations.
# Supports tool calling to allow the LLM to request additional context.
class LlmQueryService
  OLLAMA_API_URL = AppConfig.ollama_api_url
  OLLAMA_MODEL = AppConfig.ollama_model
  MAX_TOOL_ITERATIONS = 3  # Maximum number of tool calls to prevent infinite loops

  # Initialize with a query and search results from TranscriptSearchService
  # @param query_text [String] The user's question
  # @param search_results [Array<Hash>] Results from TranscriptSearchService with :episode, :podcast, :text, :start_time, :end_time, :distance
  # @param context_options [Hash] Options for context filtering (podcast_id, episode_id, listened_filter)
  def initialize(query_text, search_results, context_options = {})
    @query_text = query_text
    @search_results = search_results
    @context_options = context_options
    @all_sources = search_results.dup  # Track all sources used
    @tool_iterations = 0
  end

  # Generate a response using the LLM with the provided search results as context
  # Supports iterative tool calling for the LLM to request additional context
  # @return [Hash] Contains :response (String), :sources (Array), :query (String), :tool_calls_made (Integer), or :error (String)
  def generate_response
    return { error: "No search results provided" } if @search_results.empty?

    # Build initial messages with system prompt and user query with context
    messages = build_messages

    # Iteratively call LLM, allowing it to use tools to gather more context
    loop do
      llm_result = call_ollama_chat(messages)

      # Check if LLM made tool calls
      if llm_result[:tool_calls] && @tool_iterations < MAX_TOOL_ITERATIONS
        @tool_iterations += 1
        Rails.logger.info("LLM made #{llm_result[:tool_calls].length} tool call(s) (iteration #{@tool_iterations}/#{MAX_TOOL_ITERATIONS})")

        # Execute each tool call and add results to conversation
        messages << llm_result[:message]  # Add assistant's message with tool calls

        llm_result[:tool_calls].each do |tool_call|
          tool_result = execute_tool(tool_call)
          messages << {
            role: "tool",
            content: tool_result[:content],
            name: tool_call.dig("function", "name")
          }
        end

        # Continue loop to let LLM process tool results
        next
      elsif llm_result[:tool_calls] && @tool_iterations >= MAX_TOOL_ITERATIONS
        # Hit iteration limit, force LLM to answer with what it has
        Rails.logger.warn("Tool iteration limit reached (#{MAX_TOOL_ITERATIONS}), forcing final response")
        messages << {
          role: "user",
          content: "Please provide your final answer based on the information you have gathered so far."
        }
        llm_result = call_ollama_chat(messages, force_response: true)
      end

      # LLM provided a final response
      return {
        response: llm_result[:content],
        sources: format_all_sources,
        query: @query_text,
        tool_calls_made: @tool_iterations
      }
    end
  rescue StandardError => e
    Rails.logger.error("LLM query failed: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    { error: e.message }
  end

  private

  # Build messages array for chat API with system prompt and initial context
  # @return [Array<Hash>] Array of message hashes with role and content
  def build_messages
    context = format_context_excerpts(@search_results)

    [
      {
        role: "system",
        content: <<~SYSTEM
          You are a helpful assistant that answers questions about podcast episodes using transcript excerpts.
          You have access to a search_transcript tool to find additional context if needed.
          Always cite your sources by referencing excerpt numbers in brackets (e.g., [1], [2]).
          Only use information from the provided excerpts.
        SYSTEM
      },
      {
        role: "user",
        content: <<~USER
          Question: #{@query_text}

          Transcript excerpts:
          #{context}
        USER
      }
    ]
  end

  # Format transcript excerpts with numbering for citation
  # @param results [Array<Hash>] Search results to format
  # @return [String] Formatted context string
  def format_context_excerpts(results)
    results.map.with_index do |result, i|
      <<~CONTEXT.strip
        [#{i + 1}] Episode: "#{result[:episode].title}" (#{result[:podcast].title})
        Time: #{format_timestamp(result[:start_time])} - #{format_timestamp(result[:end_time])}
        Text: #{result[:text]}
      CONTEXT
    end.join("\n\n")
  end

  # Define available tools for the LLM
  # @return [Array<Hash>] Tool definitions in OpenAI format
  def define_tools
    [
      {
        type: "function",
        function: {
          name: "search_transcript",
          description: "Search for additional information in podcast transcripts. Use this when you need more context to answer the question completely.",
          parameters: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "The search query to find more relevant context"
              },
              num_results: {
                type: "integer",
                description: "Number of additional transcript excerpts to retrieve (1-10)",
                default: 5
              }
            },
            required: [ "query" ]
          }
        }
      }
    ]
  end

  # Execute a tool call made by the LLM
  # @param tool_call [Hash] Tool call from LLM with function name and arguments
  # @return [Hash] Tool result with :content
  def execute_tool(tool_call)
    function_name = tool_call.dig("function", "name")
    arguments = tool_call.dig("function", "arguments")

    case function_name
    when "search_transcript"
      execute_search_transcript(arguments)
    else
      { content: "Error: Unknown tool '#{function_name}'" }
    end
  end

  # Execute the search_transcript tool
  # @param args [Hash] Arguments with :query and optional :num_results
  # @return [Hash] Tool result with formatted search results
  def execute_search_transcript(args)
    query = args["query"] || args[:query]
    num_results = (args["num_results"] || args[:num_results] || 5).to_i.clamp(1, 10)

    Rails.logger.info("Executing search_transcript: query='#{query}', num_results=#{num_results}")

    # Perform new search with same context options
    search_service = TranscriptSearchService.new(query, @context_options.merge(limit: num_results))
    new_results = search_service.search

    if new_results.empty?
      return { content: "No additional relevant excerpts found for: #{query}" }
    end

    # Add new results to all_sources, avoiding duplicates
    new_results.each do |result|
      chunk_id = result[:chunk]&.id
      unless @all_sources.any? { |s| s[:chunk]&.id == chunk_id }
        @all_sources << result
      end
    end

    # Format results for LLM
    context = format_context_excerpts(new_results)
    {
      content: <<~RESULT
        Found #{new_results.length} additional excerpt(s) for "#{query}":

        #{context}
      RESULT
    }
  end

  # Call Ollama chat API with tool support
  # @param messages [Array<Hash>] Conversation messages
  # @param force_response [Boolean] Disable tools to force a final response
  # @return [Hash] Contains :content, :message, and optionally :tool_calls
  def call_ollama_chat(messages, force_response: false)
    uri = URI("#{OLLAMA_API_URL}/api/chat")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"

    body = {
      model: OLLAMA_MODEL,
      messages: messages,
      stream: false
    }

    # Add tools unless forcing final response
    body[:tools] = define_tools unless force_response

    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.read_timeout = 120  # Tool calls might take longer
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "Ollama API error: #{response.code} #{response.message}"
    end

    result = JSON.parse(response.body)
    message = result["message"]

    {
      content: message["content"],
      message: message,
      tool_calls: message["tool_calls"]
    }
  end

  # Build a prompt for the LLM that includes the query and context from search results
  # Each search result is numbered so the LLM can cite sources
  # NOTE: This method is kept for backwards compatibility but not used with tool calling
  def build_prompt
    context = @search_results.map.with_index do |result, i|
      <<~CONTEXT
        [#{i + 1}] Episode: "#{result[:episode].title}" (#{result[:podcast].title})
        Time: #{format_timestamp(result[:start_time])} - #{format_timestamp(result[:end_time])}
        Text: #{result[:text]}
      CONTEXT
    end.join("\n")

    <<~PROMPT
      You are a helpful assistant that answers questions about podcast episodes using the provided transcript excerpts.

      Answer the following question using ONLY the information from the transcript excerpts below.
      Cite your sources by referencing the excerpt numbers in brackets (e.g., [1], [2]).
      If the excerpts don't contain enough information to answer the question, say so.

      Question: #{@query_text}

      Transcript excerpts:
      #{context}

      Answer:
    PROMPT
  end

  # Call the Ollama API to generate a response
  # @param prompt [String] The full prompt with context
  # @return [String] The LLM's generated response
  def call_ollama(prompt)
    uri = URI("#{OLLAMA_API_URL}/api/generate")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = {
      model: OLLAMA_MODEL,
      prompt: prompt,
      stream: false
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "Ollama API error: #{response.code} #{response.message}"
    end

    result = JSON.parse(response.body)
    result["response"]
  end

  # Format search results into structured source citations
  # @return [Array<Hash>] Array of source metadata with episode info and timestamps
  def format_sources
    @search_results.map.with_index do |result, i|
      {
        index: i + 1,
        chunk: result[:chunk],
        episode: result[:episode],
        podcast: result[:podcast],
        episode_title: result[:episode].title,
        podcast_title: result[:podcast].title,
        start_time: result[:start_time],
        end_time: result[:end_time],
        timestamp: format_timestamp(result[:start_time]),
        text: result[:text],
        distance: result[:distance]
      }
    end
  end

  # Format all sources including those gathered via tool calls
  # @return [Array<Hash>] Array of all source metadata
  def format_all_sources
    @all_sources.map.with_index do |result, i|
      {
        index: i + 1,
        chunk: result[:chunk],
        episode: result[:episode],
        podcast: result[:podcast],
        episode_title: result[:episode].title,
        podcast_title: result[:podcast].title,
        start_time: result[:start_time],
        end_time: result[:end_time],
        timestamp: format_timestamp(result[:start_time]),
        text: result[:text],
        distance: result[:distance]
      }
    end
  end

  # Format seconds into a readable timestamp (MM:SS)
  # @param seconds [Float] Time in seconds
  # @return [String] Formatted timestamp like "16:30"
  def format_timestamp(seconds)
    return "0:00" if seconds.nil?

    minutes = (seconds / 60).to_i
    secs = (seconds % 60).to_i
    "#{minutes}:#{secs.to_s.rjust(2, '0')}"
  end
end
