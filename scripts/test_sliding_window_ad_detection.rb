# Test script for sliding window ad detection with cluster analysis
# Usage: rails runner test_sliding_window_ad_detection.rb

episode_id = 898

episode = Episode.find(episode_id)
puts "=" * 80
puts "Testing Sliding Window Ad Detection with Cluster Analysis"
puts "Episode: #{episode.title}"
puts "Podcast: #{episode.podcast.title}"
puts "=" * 80
puts ""

puts "Resetting all chunks to transcript type..."
episode.transcript_chunks.advertisement.update_all(chunk_type: "transcript")
puts ""

puts "Running vector-based detection with sliding window clustering..."
puts "Configuration:"
puts "  - Min window size: #{RepeatedSegmentAdDetectionService::MIN_WINDOW_SIZE}"
puts "  - Max window size: #{RepeatedSegmentAdDetectionService::MAX_WINDOW_SIZE}"
puts "  - Min ad ratio: #{RepeatedSegmentAdDetectionService::MIN_AD_RATIO}"
puts "  - Min chunk length: #{RepeatedSegmentAdDetectionService::MIN_CHUNK_LENGTH}"
puts ""

service = RepeatedSegmentAdDetectionService.new
result = service.analyze_episode(episode, use_vectors: true)

puts "=" * 80
puts "RESULTS"
puts "=" * 80
puts "Chunks analyzed: #{result[:chunks_analyzed]}"
puts "Within-episode matches: #{result[:within_episode_matches]}"
puts "Cross-episode matches: #{result[:cross_episode_matches]}"
puts "Total ads marked initially: #{result[:total_ads_marked]}"
puts ""
puts "Sliding Window Refinement:"
puts "  Windows found: #{result[:clusters_found]}"
puts "  False positives removed: #{result[:false_positives_removed]}"
puts "  Missed chunks added: #{result[:missed_chunks_added]}"
puts ""

# Reload episode to get fresh counts
episode.reload
total_ads = episode.transcript_chunks.advertisement.count

puts "Final ad count: #{total_ads}"
puts ""

# Check small chunks
small_ads = episode.transcript_chunks.advertisement.where("length(text) < ?", RepeatedSegmentAdDetectionService::MIN_CHUNK_LENGTH)
puts "=" * 80
puts "SMALL CHUNK ANALYSIS"
puts "=" * 80
puts "Small chunks (< #{RepeatedSegmentAdDetectionService::MIN_CHUNK_LENGTH} chars) marked as ads: #{small_ads.count}"
puts ""

if small_ads.any?
  puts "Sample small ad chunks:"
  small_ads.limit(5).each do |chunk|
    puts "  - '#{chunk.text}' (#{chunk.text.length} chars, chunk index: #{chunk.chunk_index})"
  end
  puts ""
  puts "Note: Small chunks are included in ad blocks but don't count toward window criteria"
end

puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Detection method: #{result[:detection_method]}"
puts "Total transcript chunks: #{episode.transcript_chunks.transcript.count}"
puts "Total advertisement chunks: #{total_ads}"
puts "Ad percentage: #{(total_ads.to_f / episode.transcript_chunks.count * 100).round(2)}%"
puts "=" * 80