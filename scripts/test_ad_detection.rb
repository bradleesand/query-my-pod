# Test script for ad detection with debugging
# Usage: rails runner test_ad_detection.rb

episode_id = 898
num_chunks = 5

episode = Episode.find(episode_id)
puts "=" * 80
puts "Testing Ad Detection on Episode #{episode_id}"
puts "Title: #{episode.title}"
puts "Podcast: #{episode.podcast.title}"
puts "Testing first #{num_chunks} transcript chunks"
puts "=" * 80
puts ""

# Get first few transcript chunks that haven't been analyzed
chunks = episode.transcript_chunks.transcript.order(:chunk_index).limit(num_chunks)

service = AdDetectionService.new

chunks.each_with_index do |chunk, index|
  puts "--- Chunk #{index + 1}/#{num_chunks} (ID: #{chunk.id}, Index: #{chunk.chunk_index}) ---"
  puts "Text: #{chunk.text.truncate(150)}"
  puts ""

  result = service.analyze_chunk(chunk)

  puts "LLM Response:"
  puts "  Is Ad: #{result[:is_ad]}"
  puts "  Confidence: #{result[:confidence]}"
  puts "  Reason: #{result[:reason]}"
  puts "  Above threshold (#{AdDetectionService::CONFIDENCE_THRESHOLD})? #{result[:is_ad] && result[:confidence] >= AdDetectionService::CONFIDENCE_THRESHOLD}"
  puts ""

  # Show what would happen
  if result[:is_ad] && result[:confidence] >= AdDetectionService::CONFIDENCE_THRESHOLD
    puts "  -> Would mark as ADVERTISEMENT"
  else
    puts "  -> Would mark as CONTENT"
  end
  puts ""
end

puts "=" * 80
puts "Test complete!"
puts ""
puts "Current configuration:"
puts "  AD_DETECTION_THRESHOLD: #{ENV.fetch('AD_DETECTION_THRESHOLD', '0.7')}"
puts "  OLLAMA_MODEL: #{ENV.fetch('OLLAMA_MODEL', 'qwen2.5:7b')}"
puts "  OLLAMA_API_URL: #{ENV.fetch('OLLAMA_API_URL', 'http://localhost:11434')}"
