# Test script for repeated segment ad detection
# Usage: rails runner test_repeated_segment_detection.rb

episode_id = 898

episode = Episode.find(episode_id)
puts "=" * 80
puts "Testing Repeated Segment Ad Detection"
puts "Episode: #{episode.title}"
puts "Podcast: #{episode.podcast.title}"
puts "=" * 80
puts ""

service = RepeatedSegmentAdDetectionService.new

puts "Analyzing episode for repeated segments..."
puts ""

result = service.analyze_episode(episode)

puts "RESULTS:"
puts "--------"
puts "Chunks analyzed: #{result[:chunks_analyzed]}"
puts "Within-episode matches: #{result[:within_episode_matches]}"
puts "Cross-episode matches: #{result[:cross_episode_matches]}"
puts "Total ads marked: #{result[:total_ads_marked]}"
puts ""

if result[:total_ads_marked] > 0
  puts "Detected advertisement chunks:"
  ads = episode.transcript_chunks.advertisement.order(:chunk_index)

  ads.each_with_index do |chunk, i|
    puts ""
    puts "Ad #{i + 1} (Chunk #{chunk.chunk_index}, ID: #{chunk.id})"
    puts "Confidence: #{chunk.ad_confidence}"
    puts "Text: #{chunk.text[0..300]}..."
  end
else
  puts "No advertisements detected."
end

puts ""
puts "=" * 80
