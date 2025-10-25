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

      Rails.logger.debug("LLM conversation messages:")
      Rails.logger.debug(messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n---\n"))
      Rails.logger.debug("LLM final response: #{llm_result[:content]}")

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
          You have access to tools to gather more information:
          - search_transcript: Find additional excerpts by keyword search
          - get_chunk_context: Get surrounding context for a specific chunk (use the chunk_id from excerpts)
          - get_episode_metadata: Get title and description for episodes (use the Episode ID from excerpts)

          Each excerpt is labeled with [Chunk ID] and [Episode ID: ID].

          IMPORTANT: Before citing a chunk in your final answer, you SHOULD use get_chunk_context to see what was said
          before and after it. This ensures you understand the full context and don't misrepresent what was said.

          Recommended workflow:
          1. Review initial excerpts to find relevant chunks
          2. Use get_chunk_context on promising chunks to see surrounding context (2-3 chunks before/after)
          3. Use search_transcript if you need additional information on specific topics
          4. Use get_episode_metadata to understand what episodes are about
          5. Provide your final answer with citations using [Chunk ID] format

          CRITICAL: This is a non-interactive query system. Do NOT ask follow-up questions or request user input.
          Use your available tools to gather all needed information, then provide a complete, final answer.
          If you cannot fully answer the question with available tools, state what you found and what limitations exist.

          Only use information from the provided excerpts and tool results.
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

  # Format transcript excerpts with chunk IDs for citation and tool use
  # @param results [Array<Hash>] Search results to format
  # @return [String] Formatted context string
  def format_context_excerpts(results)
    results.map do |result|
      chunk_id = result[:chunk]&.id || "unknown"
      episode_id = result[:episode]&.id || "unknown"

      <<~CONTEXT.strip
        [Chunk #{chunk_id}] Episode: "#{result[:episode].title}" (#{result[:podcast].title}) [Episode ID: #{episode_id}]
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
      },
      {
        type: "function",
        function: {
          name: "get_chunk_context",
          description: "Get surrounding transcript chunks before and after a specific chunk. Use this to see more context around an interesting excerpt.",
          parameters: {
            type: "object",
            properties: {
              chunk_id: {
                type: "integer",
                description: "The ID of the chunk to get context for"
              },
              before: {
                type: "integer",
                description: "Number of chunks to retrieve before this chunk (1-5)",
                default: 2
              },
              after: {
                type: "integer",
                description: "Number of chunks to retrieve after this chunk (1-5)",
                default: 2
              }
            },
            required: [ "chunk_id" ]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_episode_metadata",
          description: "Get title and description for specific episodes. Use this to learn more about episodes that seem relevant.",
          parameters: {
            type: "object",
            properties: {
              episode_ids: {
                type: "array",
                items: { type: "integer" },
                description: "List of episode IDs to get metadata for (1-10 episodes)"
              }
            },
            required: [ "episode_ids" ]
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
    when "get_chunk_context"
      execute_get_chunk_context(arguments)
    when "get_episode_metadata"
      execute_get_episode_metadata(arguments)
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

  # Execute the get_chunk_context tool
  # @param args [Hash] Arguments with :chunk_id and optional :before/:after
  # @return [Hash] Tool result with surrounding chunks
  def execute_get_chunk_context(args)
    chunk_id = (args["chunk_id"] || args[:chunk_id]).to_i
    before = (args["before"] || args[:before] || 2).to_i.clamp(1, 5)
    after = (args["after"] || args[:after] || 2).to_i.clamp(1, 5)

    Rails.logger.info("Executing get_chunk_context: chunk_id=#{chunk_id}, before=#{before}, after=#{after}")

    # Find the requested chunk
    chunk = TranscriptChunk.find_by(id: chunk_id)
    unless chunk
      return { content: "Error: Chunk ID #{chunk_id} not found" }
    end

    # Get surrounding chunks from the same episode, ordered by chunk_index
    # Only get transcript chunks (not title/description which have negative indices)
    surrounding_chunks = TranscriptChunk.where(episode_id: chunk.episode_id, chunk_type: "transcript")
                                       .where("chunk_index >= ? AND chunk_index <= ?",
                                              chunk.chunk_index - before,
                                              chunk.chunk_index + after)
                                       .order(:chunk_index)
                                       .includes(episode: :podcast)

    if surrounding_chunks.empty?
      return { content: "No surrounding context found for chunk #{chunk_id}" }
    end

    # Convert to result format and add to sources
    results = surrounding_chunks.map do |c|
      {
        chunk: c,
        episode: c.episode,
        podcast: c.podcast,
        text: c.text,
        start_time: c.start_time,
        end_time: c.end_time,
        distance: nil  # No distance for context chunks
      }
    end

    # Add new chunks to all_sources, avoiding duplicates
    results.each do |result|
      unless @all_sources.any? { |s| s[:chunk]&.id == result[:chunk].id }
        @all_sources << result
      end
    end

    # Format for LLM
    context = format_context_excerpts(results)
    {
      content: <<~RESULT
        Context around chunk #{chunk_id} (#{before} before, #{after} after):
        Episode: "#{chunk.episode.title}" (#{chunk.podcast.title})

        #{context}
      RESULT
    }
  end

  # Execute the get_episode_metadata tool
  # @param args [Hash] Arguments with :episode_ids array
  # @return [Hash] Tool result with episode metadata
  def execute_get_episode_metadata(args)
    episode_ids = args["episode_ids"] || args[:episode_ids] || []
    episode_ids = episode_ids.map(&:to_i).take(10)  # Limit to 10 episodes

    Rails.logger.info("Executing get_episode_metadata: episode_ids=#{episode_ids.inspect}")

    if episode_ids.empty?
      return { content: "Error: No episode IDs provided" }
    end

    episodes = Episode.where(id: episode_ids).includes(:podcast)

    if episodes.empty?
      return { content: "No episodes found for IDs: #{episode_ids.join(', ')}" }
    end

    # Format episode metadata
    metadata = episodes.map do |episode|
      <<~METADATA.strip
        Episode ID: #{episode.id}
        Title: "#{episode.title}"
        Podcast: #{episode.podcast.title}
        Description: #{episode.description || 'No description available'}
        Published: #{episode.pub_date&.strftime('%Y-%m-%d') || 'Unknown'}
        Duration: #{episode.duration ? "#{(episode.duration / 60).round} minutes" : 'Unknown'}
      METADATA
    end.join("\n\n")

    {
      content: <<~RESULT
        Episode metadata for #{episodes.count} episode(s):

        #{metadata}
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
    @all_sources.map do |result|
      {
        chunk: result[:chunk],
        episode: result[:episode],
        podcast: result[:podcast],
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
