class SearchController < ApplicationController
  def query
    @query = params[:q]
    @podcast_id = params[:podcast_id].presence
    @episode_id = params[:episode_id].presence
    @limit = params[:limit]&.to_i || ENV.fetch("SEARCH_CONTEXT_CHUNKS", 5).to_i

    if @query.blank?
      redirect_back fallback_location: root_path, alert: "Please enter a search query"
      return
    end

    # Perform vector search
    search_service = TranscriptSearchService.new(@query,
      podcast_id: @podcast_id,
      episode_id: @episode_id,
      limit: @limit)
    @search_results = search_service.search

    if @search_results.empty?
      @error = "No results found for your query"
      return
    end

    # Generate LLM response
    llm_service = LlmQueryService.new(@query, @search_results)
    @llm_response = llm_service.generate_response

    if @llm_response[:error]
      @error = @llm_response[:error]
    end

    @podcasts = Podcast.all.order(:title)
  end
end