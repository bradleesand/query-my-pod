require "text"

# Service for detecting advertisements by finding repeated segments.
# Ads are typically pre-recorded segments that repeat:
# 1. Within the same episode (mid-roll ads)
# 2. Across different episodes (same ad in multiple episodes)
class RepeatedSegmentAdDetectionService
  # Minimum text similarity threshold (0.0-1.0) to consider two chunks similar
  SIMILARITY_THRESHOLD = 0.85

  # Minimum chunk length to consider (avoid matching short filler phrases)
  MIN_CHUNK_LENGTH = 20

  # Minimum sliding window size for cluster detection
  MIN_WINDOW_SIZE = 10

  # Maximum sliding window size for cluster detection
  MAX_WINDOW_SIZE = 15

  # Minimum ratio of ads in a window to mark all chunks as ads
  MIN_AD_RATIO = 0.5

  # Analyze a single episode for repeated segments within itself and against other episodes
  # @param episode [Episode] The episode to analyze
  # @param use_vectors [Boolean] Use vector embeddings for similarity (faster, requires embeddings)
  # @return [Hash] Statistics about detected ads
  def analyze_episode(episode, use_vectors: false)
    chunks = episode.transcript_chunks.transcript_or_ad.order(:chunk_index)
                    .select { |c| c.text.length >= MIN_CHUNK_LENGTH }

    return { error: "Not enough chunks to analyze" } if chunks.size < 2

    if use_vectors
      # Ensure all chunks have embeddings
      ensure_embeddings_for_chunks(chunks)

      # Use vector-based detection
      within_episode_ads = find_within_episode_repetitions_vector(chunks)
      cross_episode_ads = find_cross_episode_repetitions_vector(episode)
    else
      # Use text-based detection
      within_episode_ads = find_within_episode_repetitions(chunks)
      cross_episode_ads = find_cross_episode_repetitions(episode)
    end

    # Mark all detected ads
    total_marked = mark_advertisements(within_episode_ads, 0.95) +
                   mark_advertisements(cross_episode_ads, 0.85)

    # Apply cluster analysis to refine detection
    cluster_stats = refine_with_cluster_analysis(episode)

    {
      episode_id: episode.id,
      chunks_analyzed: chunks.size,
      within_episode_matches: within_episode_ads.size,
      cross_episode_matches: cross_episode_ads.size,
      total_ads_marked: total_marked,
      detection_method: use_vectors ? :vector : :text,
      clusters_found: cluster_stats[:clusters_found],
      false_positives_removed: cluster_stats[:removed],
      missed_chunks_added: cluster_stats[:added]
    }
  end

  # Analyze all episodes in a podcast
  # @param podcast [Podcast] The podcast to analyze
  # @return [Hash] Statistics
  def analyze_podcast(podcast)
    episodes = podcast.episodes.transcription_completed
    results = episodes.map { |ep| analyze_episode(ep) }

    {
      podcast_id: podcast.id,
      episodes_analyzed: results.size,
      total_ads_marked: results.sum { |r| r[:total_ads_marked] || 0 }
    }
  end

  private

  # Find chunks that repeat within the same episode
  # @param chunks [Array<TranscriptChunk>] Chunks from one episode
  # @return [Array<Hash>] Repeated segments with chunk IDs
  def find_within_episode_repetitions(chunks)
    repeated = []
    processed_indices = Set.new

    chunks.each_with_index do |chunk, i|
      next if processed_indices.include?(i)

      normalized = normalize_text(chunk.text)
      matches = [ chunk.id ]

      # Compare with all later chunks
      chunks[(i + 1)..-1].each_with_index do |other_chunk, j|
        other_index = i + 1 + j
        next if processed_indices.include?(other_index)

        other_normalized = normalize_text(other_chunk.text)
        similarity = text_similarity(normalized, other_normalized)

        if similarity >= SIMILARITY_THRESHOLD
          matches << other_chunk.id
          processed_indices.add(other_index)
        end
      end

      # If we found repetitions (2+ occurrences)
      if matches.size >= 2
        repeated << {
          chunk_ids: matches,
          repetition_count: matches.size,
          text_sample: chunk.text[0..200],
          type: :within_episode
        }
        processed_indices.add(i)
      end
    end

    repeated
  end

  # Find chunks that appear in other episodes of the same podcast
  # @param episode [Episode] The episode to check
  # @return [Array<Hash>] Matching segments
  def find_cross_episode_repetitions(episode)
    podcast = episode.podcast
    other_episodes = podcast.episodes.transcription_completed.where.not(id: episode.id)

    return [] if other_episodes.empty?

    episode_chunks = episode.transcript_chunks.transcript_or_ad.order(:chunk_index)
                           .select { |c| c.text.length >= MIN_CHUNK_LENGTH }

    # Build index of other episodes' chunks
    other_chunks = []
    other_episodes.find_each do |other_ep|
      other_ep.transcript_chunks.transcript_or_ad.each do |chunk|
        next if chunk.text.length < MIN_CHUNK_LENGTH
        other_chunks << {
          id: chunk.id,
          text: normalize_text(chunk.text),
          episode_id: other_ep.id
        }
      end
    end

    return [] if other_chunks.empty?

    # Find matches
    matches = []
    episode_chunks.each do |chunk|
      normalized = normalize_text(chunk.text)

      similar = other_chunks.select do |other|
        text_similarity(normalized, other[:text]) >= SIMILARITY_THRESHOLD
      end

      if similar.any?
        matches << {
          chunk_ids: [ chunk.id ],
          matched_episodes: similar.map { |s| s[:episode_id] }.uniq,
          repetition_count: similar.size + 1,
          text_sample: chunk.text[0..200],
          type: :cross_episode
        }
      end
    end

    matches
  end

  # Mark chunks as advertisements
  # @param segments [Array<Hash>] Segments to mark
  # @param confidence [Float] Confidence score
  # @return [Integer] Number of chunks marked
  def mark_advertisements(segments, confidence)
    total = 0

    segments.each do |segment|
      chunk_ids = segment[:chunk_ids]
      TranscriptChunk.where(id: chunk_ids).find_each do |chunk|
        chunk.mark_as_advertisement!(confidence)
        total += 1
      end

      Rails.logger.info(
        "Marked #{chunk_ids.size} chunks as ad " \
        "(#{segment[:type]}, repeated #{segment[:repetition_count]} times)"
      )
    end

    total
  end

  # Normalize text for comparison
  # @param text [String] Raw text
  # @return [String] Normalized text
  def normalize_text(text)
    text.downcase
        .gsub(/[^\w\s]/, "") # Remove punctuation
        .gsub(/\s+/, " ")     # Normalize whitespace
        .strip
  end

  # Calculate similarity between two text strings
  # @param text1 [String] First text
  # @param text2 [String] Second text
  # @return [Float] Similarity score (0.0-1.0)
  def text_similarity(text1, text2)
    return 1.0 if text1 == text2
    return 0.0 if text1.empty? || text2.empty?

    # Use white similarity (word-based) for better performance
    Text::WhiteSimilarity.similarity(text1, text2)
  end

  # === VECTOR-BASED METHODS ===

  # Ensure all chunks have embeddings
  # @param chunks [Array<TranscriptChunk>] Chunks to process
  def ensure_embeddings_for_chunks(chunks)
    chunks_without_embeddings = chunks.select { |c| c.embedding.nil? }
    return if chunks_without_embeddings.empty?

    Rails.logger.info("Generating embeddings for #{chunks_without_embeddings.size} chunks")
    embedding_service = EmbeddingService.new

    chunks_without_embeddings.each do |chunk|
      embedding = embedding_service.generate(chunk.text)
      chunk.update!(embedding: embedding) if embedding
    end
  end

  # Find within-episode repetitions using vector similarity
  # @param chunks [Array<TranscriptChunk>] Chunks from one episode
  # @return [Array<Hash>] Repeated segments
  def find_within_episode_repetitions_vector(chunks)
    repeated = []
    processed_ids = Set.new

    chunks.each do |chunk|
      next if processed_ids.include?(chunk.id)
      next if chunk.embedding.nil?

      matches = [ chunk.id ]

      # Find similar chunks using nearest neighbors
      similar_chunks = chunk.transcript_or_ad
                            .nearest_neighbors(:embedding, distance: :cosine)
                            .where(id: chunks.map(&:id))
                            .where.not(id: chunk.id)
                            .limit(20) # Get top 20 candidates

      similar_chunks.each do |similar|
        similar.neighbor_distance
        # Calculate cosine similarity (1 - distance)
        similarity = 1 - similar.neighbor_distance

        if similarity >= SIMILARITY_THRESHOLD
          matches << similar.id
          processed_ids.add(similar.id)
        end
      end

      # If we found repetitions (2+ occurrences)
      if matches.size >= 2
        repeated << {
          chunk_ids: matches,
          repetition_count: matches.size,
          text_sample: chunk.text[0..200],
          type: :within_episode
        }
        processed_ids.add(chunk.id)
      end
    end

    repeated
  end

  # Find cross-episode repetitions using vector similarity
  # @param episode [Episode] The episode to check
  # @return [Array<Hash>] Matching segments
  def find_cross_episode_repetitions_vector(episode)
    podcast = episode.podcast

    return [] if podcast.episodes.transcription_completed.where.not(id: episode.id).none?

    episode_chunks = episode.transcript_chunks.transcript_or_ad
                           .where.not(embedding: nil)
                           .where("length(text) >= ?", MIN_CHUNK_LENGTH)

    matches = []

    episode_chunks.find_each do |chunk|
      # Find similar chunks in other episodes using vector search
      similar_chunks = chunk.transcript_or_ad
                            .nearest_neighbors(:embedding, distance: :cosine)
                            .joins(:episode)
                            .where(episodes: { podcast_id: podcast.id })
                            .where.not(episode_id: episode.id)
                            .where.not(ad_confidence: 0.0) # Exclude known content
                            .limit(10)

      similar_episodes = []
      similar_chunks.each do |similar|
        similarity = 1 - similar.neighbor_distance

        if similarity >= SIMILARITY_THRESHOLD
          similar_episodes << similar.episode_id
        end
      end

      if similar_episodes.any?
        matches << {
          chunk_ids: [ chunk.id ],
          matched_episodes: similar_episodes.uniq,
          repetition_count: similar_episodes.size + 1,
          text_sample: chunk.text[0..200],
          type: :cross_episode
        }
      end
    end

    matches
  end

  # === SLIDING WINDOW CLUSTER ANALYSIS ===

  # Refine ad detection using sliding window analysis
  # @param episode [Episode] The episode to analyze
  # @return [Hash] Statistics about refinement
  def refine_with_cluster_analysis(episode)
    # Get all chunks in order (including ads and transcript)
    all_chunks = episode.transcript_chunks.transcript_or_ad.order(:chunk_index).to_a

    return { clusters_found: 0, removed: 0, added: 0 } if all_chunks.size < MIN_WINDOW_SIZE

    chunks_to_mark = Set.new
    windows_processed = 0

    # Filter to only consider chunks >= MIN_CHUNK_LENGTH for window logic
    # But keep track of ALL chunks for marking
    qualifying_chunks = all_chunks.select { |c| c.text.length >= MIN_CHUNK_LENGTH }

    return { clusters_found: 0, removed: 0, added: 0 } if qualifying_chunks.size < MIN_WINDOW_SIZE

    # Slide the window across qualifying chunks only
    # Use variable window size: start with MIN_WINDOW_SIZE and expand if needed
    (0..qualifying_chunks.size - MIN_WINDOW_SIZE).each do |start_idx|
      # Start with minimum window size
      window_size = MIN_WINDOW_SIZE
      window = nil

      # Try expanding window until we find ads at both ends or hit max size
      while window_size <= MAX_WINDOW_SIZE && start_idx + window_size <= qualifying_chunks.size
        window = qualifying_chunks[start_idx, window_size]
        break if window.size < window_size # Not enough chunks remaining

        first_chunk = window.first
        last_chunk = window.last

        # If first is ad and last is ad, we found a good window
        if first_chunk.advertisement? && last_chunk.advertisement?
          break
        end

        # If first is ad but last is not, try expanding
        if first_chunk.advertisement? && !last_chunk.advertisement?
          window_size += 1
          next
        end

        # If first is not an ad, this window won't work - break and move to next start position
        break
      end

      # Skip if we don't have a valid window
      next unless window && window.size >= MIN_WINDOW_SIZE

      first_chunk = window.first
      last_chunk = window.last

      # Check if first and last chunks are ads
      next unless first_chunk.advertisement? && last_chunk.advertisement?

      # Calculate ad ratio in window (only counting qualifying chunks)
      ad_count = window.count(&:advertisement?)
      ad_ratio = ad_count.to_f / window.size

      # If ratio meets threshold, mark all chunks in this range as ads
      if ad_ratio >= MIN_AD_RATIO
        # Get the chunk_index range of this window
        start_index = first_chunk.chunk_index
        end_index = last_chunk.chunk_index

        # Mark ALL chunks in this range (including small ones)
        all_chunks.each do |chunk|
          if chunk.chunk_index >= start_index && chunk.chunk_index <= end_index
            chunks_to_mark.add(chunk.id)
          end
        end

        windows_processed += 1
      end
    end

    # Mark all chunks that should be ads
    added = 0
    removed = 0

    # First, mark all chunks in qualifying windows as ads
    chunks_to_mark.each do |chunk_id|
      chunk = TranscriptChunk.find(chunk_id)
      unless chunk.advertisement?
        chunk.mark_as_advertisement!(0.8) # Medium-high confidence from cluster
        added += 1
      end
    end

    # Then, handle all other chunks
    all_chunk_ids = all_chunks.map(&:id).to_set

    # Mark all chunks not in qualifying windows as content (if they're currently ads or unanalyzed)
    (all_chunk_ids - chunks_to_mark).each do |chunk_id|
      chunk = TranscriptChunk.find(chunk_id)

      # If it's currently marked as an ad, change to content
      if chunk.advertisement?
        chunk.mark_as_content!(0.3) # Low confidence it's an ad
        removed += 1
      # If it's never been analyzed, mark as content with very low ad confidence
      elsif chunk.ad_confidence.nil?
        chunk.mark_as_content!(0.1) # Very low confidence it's an ad
      end
    end

    {
      clusters_found: windows_processed,
      removed: removed,
      added: added
    }
  end
end
