require "net/http"
require "json"

# Service for querying a local LLM (Ollama) with search results to generate cited responses.
# Takes search results from TranscriptSearchService and builds a prompt with context,
# then calls Ollama API to generate a natural language response with citations.
class LlmQueryService
  OLLAMA_API_URL = AppConfig.ollama_api_url
  OLLAMA_MODEL = AppConfig.ollama_model

  # Initialize with a query and search results from TranscriptSearchService
  # @param query_text [String] The user's question
  # @param search_results [Array<Hash>] Results from TranscriptSearchService with :episode, :podcast, :text, :start_time, :end_time, :distance
  def initialize(query_text, search_results)
    @query_text = query_text
    @search_results = search_results
  end

  # Generate a response using the LLM with the provided search results as context
  # @return [Hash] Contains :response (String), :sources (Array), :query (String), or :error (String)
  def generate_response
    return { error: "No search results provided" } if @search_results.empty?

    prompt = build_prompt
    llm_response = call_ollama(prompt)

    {
      response: llm_response,
      sources: format_sources,
      query: @query_text
    }
  rescue StandardError => e
    Rails.logger.error("LLM query failed: #{e.message}")
    { error: e.message }
  end

  private

  # Build a prompt for the LLM that includes the query and context from search results
  # Each search result is numbered so the LLM can cite sources
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

