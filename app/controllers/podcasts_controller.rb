class PodcastsController < ApplicationController
  before_action :set_podcast, only: %i[ show edit update destroy refresh ]

  # GET /podcasts or /podcasts.json
  def index
    @podcasts = Podcast.all
    @pending_imports = PodcastImportTask.where(status: [:pending, :processing]).order(created_at: :desc)
  end

  # GET /podcasts/1 or /podcasts/1.json
  def show
    sort_order = params[:sort] == 'asc' ? :asc : :desc
    @pagy, @episodes = pagy(@podcast.episodes.order(pub_date: sort_order), limit: 25)
    @sort_order = sort_order
  end

  # POST /podcasts/1/refresh
  def refresh
    PodcastRefreshJob.perform_later(@podcast.id)
    
    respond_to do |format|
      format.html { redirect_to @podcast, notice: "Podcast refresh has been queued. New episodes will appear shortly." }
      format.turbo_stream do
        flash.now[:notice] = "Podcast refresh has been queued. New episodes will appear shortly."
      end
    end
  end

  # GET /podcasts/new
  def new
    @podcast = Podcast.new
  end

  # GET /podcasts/1/edit
  def edit
  end

  # POST /podcasts or /podcasts.json
  def create
    @podcast = Podcast.new(podcast_params)

    respond_to do |format|
      if @podcast.save
        format.html { redirect_to @podcast, notice: "Podcast was successfully created." }
        format.json { render :show, status: :created, location: @podcast }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @podcast.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /podcasts/1 or /podcasts/1.json
  def update
    respond_to do |format|
      if @podcast.update(podcast_params)
        format.html { redirect_to @podcast, notice: "Podcast was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @podcast }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @podcast.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /podcasts/1 or /podcasts/1.json
  def destroy
    @podcast.destroy!

    respond_to do |format|
      format.html { redirect_to podcasts_path, notice: "Podcast was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_podcast
      @podcast = Podcast.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def podcast_params
      params.expect(podcast: [ :rss_url, :title, :description, :link, :language, :category, :explicit, :image_url, :guid, :author, :copywrite ])
    end
end
