class SearchController < ApplicationController
  def query
    @query = params[:q]
    @podcast_id = params[:podcast_id].presence
    @episode_id = params[:episode_id].presence

    if @query.blank?
      if turbo_frame_request?
        render partial: "search/results", locals: { error: "Please enter a search query", llm_response: nil, query: @query, podcast_id: @podcast_id, episode_id: @episode_id }
      else
        redirect_back fallback_location: root_path, alert: "Please enter a search query"
      end
      return
    end

    # Build page context for LLM
    page_context = {}
    if @episode_id
      episode = Episode.find_by(id: @episode_id)
      if episode
        page_context[:episode_id] = episode.id
        page_context[:episode_title] = episode.title
        page_context[:podcast_id] = episode.podcast_id
        page_context[:podcast_title] = episode.podcast.title
      end
    elsif @podcast_id
      podcast = Podcast.find_by(id: @podcast_id)
      if podcast
        page_context[:podcast_id] = podcast.id
        page_context[:podcast_title] = podcast.title
      end
    end

    # LLM will gather all information via tools
    llm_service = LlmQueryService.new(@query, page_context)
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