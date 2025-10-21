namespace :ads do
  desc "Detect advertisements in all episodes with transcripts"
  task detect_all: :environment do
    puts "Detecting advertisements in all transcribed episodes..."

    episodes = Episode.transcription_completed
    total_episodes = episodes.count
    processed = 0
    total_ads = 0

    episodes.find_each do |episode|
      # Skip if no transcript chunks
      next unless episode.transcript_chunks.any?

      # Skip if already fully analyzed
      next unless episode.transcript_chunks.transcript.not_ad_analyzed.any?

      print "Processing episode #{episode.id} (#{episode.title})... "
      result = AdDetectionService.new.process_episode(episode)

      processed += 1
      total_ads += result[:ads_detected]

      puts "✓ #{result[:ads_detected]} ads found in #{result[:total_chunks]} chunks"
    rescue => e
      puts "✗ Error: #{e.message}"
    end

    puts "\nComplete!"
    puts "Episodes processed: #{processed}/#{total_episodes}"
    puts "Total advertisements detected: #{total_ads}"
  end

  desc "Detect advertisements in a specific episode"
  task :detect_episode, [:episode_id] => :environment do |t, args|
    unless args[:episode_id]
      puts "Usage: rails ads:detect_episode[EPISODE_ID]"
      exit 1
    end

    episode = Episode.find_by(id: args[:episode_id])

    unless episode
      puts "Episode #{args[:episode_id]} not found"
      exit 1
    end

    unless episode.transcription_completed?
      puts "Episode #{episode.id} has not been transcribed yet"
      exit 1
    end

    unless episode.transcript_chunks.any?
      puts "Episode #{episode.id} has no transcript chunks"
      exit 1
    end

    puts "Detecting advertisements in episode #{episode.id}: #{episode.title}"
    puts "Podcast: #{episode.podcast.title}"
    puts ""

    result = AdDetectionService.new.process_episode(episode)

    puts "✓ Detection complete!"
    puts "  Chunks analyzed: #{result[:total_chunks]}"
    puts "  Advertisements detected: #{result[:ads_detected]}"

    if result[:ads_detected] > 0
      puts "\nAdvertisement chunks:"
      episode.transcript_chunks.advertisement.order(:chunk_index).each do |chunk|
        timestamp = chunk.start_time ? "(#{format_time(chunk.start_time)})" : ""
        puts "  - Chunk ##{chunk.chunk_index} #{timestamp}: #{chunk.text.truncate(80)}"
        puts "    Confidence: #{(chunk.ad_confidence * 100).round(1)}%"
      end
    end
  end

  desc "Review detected advertisements across all episodes"
  task review: :environment do
    puts "Advertisement Detection Review"
    puts "=" * 80
    puts ""

    ad_chunks = TranscriptChunk.advertisement.includes(episode: :podcast).order("episodes.pub_date DESC")

    if ad_chunks.empty?
      puts "No advertisements detected yet. Run 'rails ads:detect_all' first."
      exit 0
    end

    grouped_by_episode = ad_chunks.group_by(&:episode)

    grouped_by_episode.each do |episode, chunks|
      puts "Episode: #{episode.title}"
      puts "Podcast: #{episode.podcast.title}"
      puts "Ads detected: #{chunks.count}"
      puts ""

      chunks.sort_by(&:chunk_index).each do |chunk|
        timestamp = chunk.start_time ? format_time(chunk.start_time) : "unknown"
        confidence = (chunk.ad_confidence * 100).round(1)

        puts "  [#{timestamp}] Confidence: #{confidence}%"
        puts "  #{chunk.text.truncate(100)}"
        puts ""
      end

      puts "-" * 80
      puts ""
    end

    puts "Total episodes with ads: #{grouped_by_episode.count}"
    puts "Total ad chunks: #{ad_chunks.count}"
  end

  desc "Show advertisement detection statistics"
  task stats: :environment do
    puts "Advertisement Detection Statistics"
    puts "=" * 80
    puts ""

    # Use enum scopes
    total_content_chunks = TranscriptChunk.content.count  # transcript + title + description (not ads)
    ad_chunks = TranscriptChunk.advertisement.count
    analyzed_chunks = TranscriptChunk.ad_analyzed.count
    unanalyzed_chunks = TranscriptChunk.not_ad_analyzed.count

    puts "Overall Statistics:"
    puts "  Total content chunks: #{total_content_chunks}"
    puts "  Advertisement chunks: #{ad_chunks}"
    puts "  Analyzed chunks: #{analyzed_chunks}"
    puts "  Unanalyzed chunks: #{unanalyzed_chunks}"

    if analyzed_chunks > 0
      ad_percentage = (ad_chunks.to_f / analyzed_chunks * 100).round(2)
      puts "  Advertisement rate: #{ad_percentage}%"
    end

    puts ""
    puts "By Podcast:"
    puts ""

    Podcast.find_each do |podcast|
      episodes = podcast.episodes.transcription_completed
      next unless episodes.any?

      podcast_ad_chunks = TranscriptChunk.advertisement
                                        .joins(:episode)
                                        .where(episodes: { podcast_id: podcast.id })
                                        .count

      podcast_content_chunks = TranscriptChunk.content
                                             .joins(:episode)
                                             .where(episodes: { podcast_id: podcast.id })
                                             .count

      podcast_total_chunks = podcast_ad_chunks + podcast_content_chunks

      next if podcast_total_chunks.zero?

      ad_rate = (podcast_ad_chunks.to_f / podcast_total_chunks * 100).round(2)

      puts "  #{podcast.title}"
      puts "    Episodes: #{episodes.count}"
      puts "    Total chunks: #{podcast_total_chunks}"
      puts "    Ad chunks: #{podcast_ad_chunks} (#{ad_rate}%)"
      puts ""
    end
  end

  desc "Reset ad detection for an episode (clears ad_confidence)"
  task :reset_episode, [:episode_id] => :environment do |t, args|
    unless args[:episode_id]
      puts "Usage: rails ads:reset_episode[EPISODE_ID]"
      exit 1
    end

    episode = Episode.find_by(id: args[:episode_id])

    unless episode
      puts "Episode #{args[:episode_id]} not found"
      exit 1
    end

    ad_count = episode.transcript_chunks.advertisement.count

    # Reset all chunks back to transcript type with no confidence
    episode.transcript_chunks.advertisement.update_all(chunk_type: "transcript")
    episode.transcript_chunks.update_all(ad_confidence: nil)

    puts "✓ Reset #{ad_count} advertisement chunks for episode #{episode.id}"
    puts "  Run 'rails ads:detect_episode[#{episode.id}]' to re-analyze"
  end

  # Helper method to format timestamps
  def format_time(seconds)
    return "0:00" if seconds.nil?

    minutes = (seconds / 60).to_i
    secs = (seconds % 60).to_i
    "#{minutes}:#{secs.to_s.rjust(2, '0')}"
  end
end
