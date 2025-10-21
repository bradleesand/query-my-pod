require "net/http"
require "json"

# Service for detecting advertisements in transcript chunks using LLM analysis.
# Analyzes text content to identify sponsor mentions, product pitches, and ad patterns.
class AdDetectionService
  # Minimum confidence threshold to mark as advertisement (0.0-1.0)
  CONFIDENCE_THRESHOLD = AppConfig.ad_detection_threshold

  # Analyze a single transcript chunk for advertisement content
  # @param chunk [TranscriptChunk] The chunk to analyze
  # @return [Hash] { is_ad: Boolean, confidence: Float, reason: String }
  def analyze_chunk(chunk)
    return { is_ad: false, confidence: 0.0, reason: "Empty text" } if chunk.text.blank?

    result = call_llm(chunk.text)

    {
      is_ad: result[:is_ad],
      confidence: result[:confidence],
      reason: result[:reason]
    }
  rescue StandardError => e
    Rails.logger.error("Ad detection failed for chunk #{chunk.id}: #{e.message}")
    { is_ad: false, confidence: 0.0, reason: "Error: #{e.message}" }
  end

  # Process all chunks in an episode
  # @param episode [Episode] The episode to process
  # @return [Hash] Summary statistics
  def process_episode(episode)
    # Only process transcript chunks that haven't been analyzed yet
    chunks = episode.transcript_chunks.transcript.not_ad_analyzed
    ads_detected = 0
    total_processed = 0

    chunks.find_each do |chunk|
      result = analyze_chunk(chunk)
      total_processed += 1

      # Always store confidence (as "confidence this is an ad")
      if result[:is_ad] && result[:confidence] >= CONFIDENCE_THRESHOLD
        chunk.mark_as_advertisement!(result[:confidence])
        ads_detected += 1
        Rails.logger.info("Detected ad in chunk #{chunk.id}: #{result[:reason]} (confidence: #{result[:confidence]})")
      else
        # Store as content with the confidence it's an ad (which should be low)
        chunk.mark_as_content!(result[:confidence])
      end
    end

    {
      total_chunks: total_processed,
      ads_detected: ads_detected,
      episode_id: episode.id
    }
  end

  private

  # Build the prompt for ad detection
  # @param text [String] The transcript text to analyze
  # @return [String] The prompt
  def build_prompt(text)
    <<~PROMPT
      You are an advertisement detection system. Analyze the following podcast transcript excerpt and determine if it contains advertising content.

      Common advertisement patterns:
      - Sponsor mentions ("This episode is brought to you by...", "Thanks to our sponsor...")
      - Product pitches with promotional language
      - Promo codes or special offers ("Use code PODCAST20 for 20% off...")
      - URLs or website mentions for products/services
      - Mid-roll ad transitions ("And now a word from our sponsor...")
      - Pre-roll or post-roll promotional content
      - Overly promotional language about products/services

      NOT advertisements:
      - Discussion of products/services in context of the show topic
      - Guest introductions or credentials
      - Episode announcements or show information
      - Patreon or listener support mentions (unless heavily promotional)
      - Brief mentions of tools/products used in discussion

      Transcript excerpt:
      "#{text}"

      Respond in JSON format with:
      {
        "is_ad": true/false,
        "confidence": 0.0-1.0,
        "reason": "brief explanation"
      }

      Be conservative - only mark as advertisement if you're confident it's promotional content, not organic discussion.
    PROMPT
  end

  # Call the LLM to analyze the text
  # @param text [String] The text to analyze
  # @return [Hash] Parsed response with :is_ad, :confidence, :reason
  def call_llm(text)
    uri = URI("#{AppConfig.ollama_api_url}/api/generate")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = {
      model: AppConfig.ollama_model,
      prompt: build_prompt(text),
      stream: false,
      format: "json"
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "Ollama API error: #{response.code} #{response.message}"
    end

    result = JSON.parse(response.body)
    llm_response = JSON.parse(result["response"])

    {
      is_ad: llm_response["is_ad"],
      confidence: llm_response["confidence"].to_f,
      reason: llm_response["reason"]
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse LLM response: #{e.message}")
    { is_ad: false, confidence: 0.0, reason: "Parse error" }
  end
end
