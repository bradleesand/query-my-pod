class EpisodesController < ApplicationController
  before_action :set_episode, only: %i[ show edit update destroy download_audio transcribe serve_audio ]

  # GET /episodes or /episodes.json
  def index
    @episodes = Episode.all
  end

  # GET /episodes/1 or /episodes/1.json
  def show
  end

  # GET /episodes/new
  def new
    @episode = Episode.new
  end

  # GET /episodes/1/edit
  def edit
  end

  # POST /episodes or /episodes.json
  def create
    @episode = Episode.new(episode_params)

    respond_to do |format|
      if @episode.save
        format.html { redirect_to @episode, notice: "Episode was successfully created." }
        format.json { render :show, status: :created, location: @episode }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @episode.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /episodes/1 or /episodes/1.json
  def update
    respond_to do |format|
      if @episode.update(episode_params)
        format.html { redirect_to @episode, notice: "Episode was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @episode }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @episode.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /episodes/1 or /episodes/1.json
  def destroy
    @episode.destroy!

    respond_to do |format|
      format.html { redirect_to episodes_path, notice: "Episode was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # POST /episodes/1/download_audio
  def download_audio
    # Just download, no other steps
    EpisodeProcessingJob.perform_later(@episode.id, [:download])
    
    respond_to do |format|
      format.html { redirect_to @episode, notice: "Audio download started." }
      format.json { render json: { status: "queued" }, status: :accepted }
    end
  end

  # POST /episodes/1/transcribe
  def transcribe
    # Full pipeline: download, trim ads, transcribe
    EpisodeProcessingJob.perform_later(@episode.id, [:download, :trim_ads, :transcribe])
    
    respond_to do |format|
      format.html { redirect_to @episode, notice: "Transcription started." }
      format.json { render json: { status: "queued" }, status: :accepted }
    end
  end

  # GET /episodes/1/audio
  def serve_audio
    if @episode.local_audio_path.present? && File.exist?(@episode.local_audio_path) && @episode.enclosure_type.present?
      send_file @episode.local_audio_path, 
                type: @episode.enclosure_type,
                disposition: 'inline'
    else
      redirect_to @episode.enclosure_url, allow_other_host: true
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_episode
      @episode = Episode.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def episode_params
      params.expect(episode: [ :podcast_id, :title, :enclosure_length, :enclosure_type, :enclosure_url, :guid, :link, :pub_date, :description, :duration, :image_url, :explicit, :transcript_url, :transcript_type, :episode_number, :season_number, :episode_type, :block ])
    end
end
