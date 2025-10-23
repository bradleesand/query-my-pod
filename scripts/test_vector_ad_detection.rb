# Test script to compare text-based vs vector-based ad detection
# Usage: rails runner test_vector_ad_detection.rb

episode_id = 898

episode = Episode.find(episode_id)
puts "=" * 80
puts "Comparing Ad Detection Methods"
puts "Episode: #{episode.title}"
puts "Podcast: #{episode.podcast.title}"
puts "=" * 80
puts ""

# First, reset all chunks to transcript (clear previous ad detections)
puts "Resetting all chunks to transcript type..."
episode.transcript_chunks.advertisement.update_all(chunk_type: "transcript")
puts ""

service = RepeatedSegmentAdDetectionService.new

# Test text-based detection
puts "=" * 80
puts "TEXT-BASED DETECTION"
puts "=" * 80
text_start = Time.now
text_result = service.analyze_episode(episode, use_vectors: false)
text_duration = Time.now - text_start

puts "Duration: #{text_duration.round(2)}s"
puts "Chunks analyzed: #{text_result[:chunks_analyzed]}"
puts "Within-episode matches: #{text_result[:within_episode_matches]}"
puts "Cross-episode matches: #{text_result[:cross_episode_matches]}"
puts "Total ads marked: #{text_result[:total_ads_marked]}"
puts ""

# Save text results
text_ad_ids = episode.transcript_chunks.advertisement.pluck(:id).sort

# Reset for vector test
puts "Resetting for vector-based test..."
episode.transcript_chunks.advertisement.update_all(chunk_type: "transcript")
puts ""

# Test vector-based detection
puts "=" * 80
puts "VECTOR-BASED DETECTION"
puts "=" * 80
vector_start = Time.now
vector_result = service.analyze_episode(episode, use_vectors: true)
vector_duration = Time.now - vector_start

puts "Duration: #{vector_duration.round(2)}s"
puts "Chunks analyzed: #{vector_result[:chunks_analyzed]}"
puts "Within-episode matches: #{vector_result[:within_episode_matches]}"
puts "Cross-episode matches: #{vector_result[:cross_episode_matches]}"
puts "Total ads marked: #{vector_result[:total_ads_marked]}"
puts ""

# Save vector results
vector_ad_ids = episode.transcript_chunks.advertisement.pluck(:id).sort

# Compare results
puts "=" * 80
puts "COMPARISON"
puts "=" * 80
puts "Speed improvement: #{(text_duration / vector_duration).round(2)}x faster" if vector_duration > 0
puts ""

# Find differences
text_only = text_ad_ids - vector_ad_ids
vector_only = vector_ad_ids - text_ad_ids
both = text_ad_ids & vector_ad_ids

puts "Ads found by both methods: #{both.size}"
puts "Ads found only by text method: #{text_only.size}"
puts "Ads found only by vector method: #{vector_only.size}"
puts ""

if text_only.any?
  puts "Sample chunks found only by text method:"
  TranscriptChunk.where(id: text_only.first(3)).each do |chunk|
    puts "  - Chunk #{chunk.chunk_index}: #{chunk.text[0..100]}..."
  end
  puts ""
end

if vector_only.any?
  puts "Sample chunks found only by vector method:"
  TranscriptChunk.where(id: vector_only.first(3)).each do |chunk|
    puts "  - Chunk #{chunk.chunk_index}: #{chunk.text[0..100]}..."
  end
  puts ""
end

puts "=" * 80
puts "Recommendation: Use #{vector_duration < text_duration ? 'VECTOR' : 'TEXT'}-based detection"
puts "=" * 80
