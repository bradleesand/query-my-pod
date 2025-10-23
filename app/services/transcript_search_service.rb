class TranscriptSearchService
  # Weights for different chunk types (higher = more important)
  CHUNK_TYPE_WEIGHTS = {
    "title" => 3.0,        # Title matches are most important
    "description" => 2.0,  # Description matches are very important
    "transcript" => 1.0,   # Regular transcript matches are baseline
    "advertisement" => 0.5 # Ads are less important (if included)
  }.freeze

  def initialize(query_text, options = {})
    @query_text = query_text
    @podcast_id = options[:podcast_id]
    @episode_id = options[:episode_id]
    @limit = options[:limit] || 5
    @include_ads = options[:include_ads] || false
    @listened_filter = options[:listened_filter] || "all"
    @embedding_service = EmbeddingService.new
  end

  def search
    return [] if @query_text.blank?

    # Generate embedding for the query
    query_embedding = @embedding_service.generate(@query_text)
    return [] unless query_embedding

    # Build base query for chunks with embeddings
    chunks = TranscriptChunk.where.not(embedding: nil)

    # Exclude advertisements by default unless specifically requested
    chunks = chunks.content unless @include_ads

    # Filter by episode if specified (most specific)
    if @episode_id
      chunks = chunks.where(episode_id: @episode_id)
    # Filter by podcast if specified
    elsif @podcast_id
      chunks = chunks.joins(:episode).where(episodes: { podcast_id: @podcast_id })
    end

    # Apply listened filter
    case @listened_filter
    when "unlistened"
      chunks = chunks.joins(:episode).merge(Episode.unlistened)
    when "listened"
      chunks = chunks.joins(:episode).merge(Episode.listened)
      # "all" - no filter
    end

    # Perform vector similarity search - get more results initially to account for re-ranking
    raw_results = chunks.nearest_neighbors(:embedding, query_embedding, distance: "cosine")
                       .limit(@limit * 3) # Get 3x results for re-ranking
                       .includes(episode: :podcast)

    # Apply weights based on chunk type and re-rank
    weighted_results = raw_results.map do |chunk|
      weight = CHUNK_TYPE_WEIGHTS[chunk.chunk_type] || 1.0

      # Convert distance to similarity (1 - distance for cosine)
      # Lower distance = higher similarity
      similarity = 1.0 - chunk.neighbor_distance

      # Apply weight to boost similarity
      weighted_score = similarity * weight

      {
        chunk: chunk,
        episode: chunk.episode,
        podcast: chunk.podcast,
        text: chunk.text,
        start_time: chunk.start_time,
        end_time: chunk.end_time,
        distance: chunk.neighbor_distance,
        similarity: similarity,
        weight: weight,
        weighted_score: weighted_score
      }
    end

    # Sort by weighted score (highest first) and limit to requested amount
    weighted_results.sort_by { |r| -r[:weighted_score] }.take(@limit)
  end
end
