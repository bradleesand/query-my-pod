class SearchController < ApplicationController
  def query
    @query = params[:q]
    @context = params[:context] || "all"
    @current_podcast_id = params[:current_podcast_id].presence
    @current_episode_id = params[:current_episode_id].presence
    @limit = params[:limit]&.to_i || AppConfig.search_context_chunks

    # Determine actual search scope based on context
    case @context
    when "episode"
      @podcast_id = nil
      @episode_id = @current_episode_id
    when "podcast"
      @podcast_id = @current_podcast_id
      @episode_id = nil
    when "all"
      @podcast_id = nil
      @episode_id = nil
    end

    if @query.blank?
      if turbo_frame_request?
        render partial: "search/results", locals: { error: "Please enter a search query", llm_response: nil, query: @query, podcast_id: @podcast_id, episode_id: @episode_id }
      else
        redirect_back fallback_location: root_path, alert: "Please enter a search query"
      end
      return
    end

    # Perform vector search
    listened_filter = params[:listened_filter] || "all"
    search_service = TranscriptSearchService.new(@query,
      podcast_id: @podcast_id,
      episode_id: @episode_id,
      limit: @limit,
      listened_filter: listened_filter)
    @search_results = search_service.search

    if @search_results.empty?
      @error = "No results found for your query"
      if turbo_frame_request?
        render partial: "search/results", locals: { error: @error, llm_response: nil, query: @query, podcast_id: @podcast_id, episode_id: @episode_id }
      end
      return
    end

    # Generate LLM response
    llm_service = LlmQueryService.new(@query, @search_results)
    @llm_response = llm_service.generate_response

    if @llm_response[:error]
      @error = @llm_response[:error]
    end

    if turbo_frame_request?
      render partial: "search/results", locals: { error: @error, llm_response: @llm_response, query: @query, podcast_id: @podcast_id, episode_id: @episode_id }
    else
      # Full page render for non-turbo requests
      @podcasts = Podcast.all.order(:title)
    end
  end
end