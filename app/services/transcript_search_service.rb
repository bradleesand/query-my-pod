class TranscriptSearchService
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

    # Perform vector similarity search
    results = chunks.nearest_neighbors(:embedding, query_embedding, distance: "cosine")
                   .limit(@limit)
                   .includes(episode: :podcast)

    # Return results with metadata
    results.map do |chunk|
      {
        chunk: chunk,
        episode: chunk.episode,
        podcast: chunk.podcast,
        text: chunk.text,
        start_time: chunk.start_time,
        end_time: chunk.end_time,
        distance: chunk.neighbor_distance
      }
    end
  end
end