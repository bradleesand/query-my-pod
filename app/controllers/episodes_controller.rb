class EpisodesController < ApplicationController
  before_action :set_episode, only: %i[ show edit update destroy download_audio redownload_audio transcribe serve_audio reprocess_chunks reprocess_embeddings reprocess_ads reset_processing bulk_update_chunks toggle_listened ]

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
    EpisodeProcessingJob.perform_later(@episode.id, [ :download ])

    respond_to do |format|
      format.html { redirect_to @episode, notice: "Audio download started." }
      format.json { render json: { status: "queued" }, status: :accepted }
    end
  end

  # POST /episodes/1/redownload_audio
  def redownload_audio
    # Delete existing audio file
    if @episode.local_audio_exists?
      File.delete(@episode.audio_path)
    end

    # Reset download status and metadata
    @episode.update!(
      download_status: nil,
      local_audio_size: nil,
      local_audio_checksum: nil
    )

    # Re-download
    EpisodeProcessingJob.perform_later(@episode.id, [ :download ])

    respond_to do |format|
      format.html { redirect_to @episode, notice: "Re-downloading audio..." }
      format.json { render json: { status: "queued" }, status: :accepted }
    end
  end

  # POST /episodes/1/transcribe
  def transcribe
    EpisodeProcessingJob.perform_later(@episode.id) # uses default pipeline

    respond_to do |format|
      format.html { redirect_to @episode, notice: "Transcription started." }
      format.json { render json: { status: "queued" }, status: :accepted }
    end
  end

  # GET /episodes/1/audio
  def serve_audio
    if @episode.local_audio_exists? && @episode.enclosure_type.present?
      # Support HTTP range requests for audio seeking
      file_path = @episode.audio_path
      file_size = File.size(file_path)

      # Check if this is a range request
      if request.headers["Range"]
        # Parse the range header (format: "bytes=start-end")
        range = request.headers["Range"]
        match = range.match(/bytes=(\d+)-(\d*)/)

        if match
          range_start = match[1].to_i
          range_end = match[2].present? ? match[2].to_i : file_size - 1
          range_end = [ range_end, file_size - 1 ].min

          content_length = range_end - range_start + 1

          response.headers["Content-Range"] = "bytes #{range_start}-#{range_end}/#{file_size}"
          response.headers["Accept-Ranges"] = "bytes"
          response.headers["Content-Length"] = content_length.to_s

          send_data File.binread(file_path, content_length, range_start),
                    type: @episode.enclosure_type,
                    disposition: "inline",
                    status: :partial_content
        else
          head :bad_request
        end
      else
        # Normal request without range
        response.headers["Accept-Ranges"] = "bytes"
        send_file file_path,
                  type: @episode.enclosure_type,
                  disposition: "inline"
      end
    else
      redirect_to @episode.enclosure_url, allow_other_host: true
    end
  end

  # POST /episodes/1/reprocess_chunks
  def reprocess_chunks
    # Delete existing chunks and re-chunk
    @episode.transcript_chunks.destroy_all
    EpisodeProcessingJob.perform_later(@episode.id, [ :chunk_transcript ])

    respond_to do |format|
      format.html { redirect_to @episode, notice: "Re-chunking transcript..." }
      format.json { render json: { status: "queued" }, status: :accepted }
    end
  end

  # POST /episodes/1/reprocess_embeddings
  def reprocess_embeddings
    # Clear existing embeddings and regenerate
    @episode.transcript_chunks.update_all(embedding: nil)
    EpisodeProcessingJob.perform_later(@episode.id, [ :generate_embeddings ])

    respond_to do |format|
      format.html { redirect_to @episode, notice: "Regenerating embeddings..." }
      format.json { render json: { status: "queued" }, status: :accepted }
    end
  end

  # POST /episodes/1/reprocess_ads
  def reprocess_ads
    # Reset ad detection
    @episode.transcript_chunks.advertisement.update_all(chunk_type: "transcript")
    @episode.transcript_chunks.update_all(ad_confidence: nil)
    EpisodeProcessingJob.perform_later(@episode.id, [ :detect_ads_in_transcript ])

    respond_to do |format|
      format.html { redirect_to @episode, notice: "Re-detecting advertisements..." }
      format.json { render json: { status: "queued" }, status: :accepted }
    end
  end

  # POST /episodes/1/reset_processing
  def reset_processing
    # Complete reset: delete chunks, clear statuses, delete local audio
    @episode.transcript_chunks.destroy_all
    @episode.update!(
      transcription_status: nil,
      download_status: nil,
      generated_transcript: nil
    )

    # Delete local audio file if it exists
    if @episode.local_audio_exists?
      File.delete(@episode.audio_path)
      @episode.update!(local_audio_size: nil, local_audio_checksum: nil)
    end

    respond_to do |format|
      format.html { redirect_to @episode, notice: "Episode processing reset. Ready to start fresh." }
      format.json { render json: { status: "reset" }, status: :ok }
    end
  end

  # POST /episodes/1/bulk_update_chunks
  def bulk_update_chunks
    chunk_ids = params[:chunk_ids]
    chunk_type = params[:chunk_type]

    unless chunk_ids.is_a?(Array) && %w[transcript advertisement].include?(chunk_type)
      return render json: { error: "Invalid parameters" }, status: :bad_request
    end

    # Only update chunks that belong to this episode
    chunks = @episode.transcript_chunks.where(id: chunk_ids)

    if chunks.empty?
      return render json: { error: "No chunks found" }, status: :not_found
    end

    # Update chunks with manual classification confidence
    confidence = chunk_type == "advertisement" ? 1.0 : 0.0
    chunks.update_all(chunk_type: chunk_type, ad_confidence: confidence)

    Rails.logger.info("Manually updated #{chunks.count} chunks to #{chunk_type} for episode #{@episode.id}")

    render json: { updated: chunks.count }, status: :ok
  end

  # POST /episodes/1/toggle_listened
  def toggle_listened
    if @episode.listened?
      @episode.mark_as_unlistened!
      message = "Marked as unlistened"
    else
      @episode.mark_as_listened!
      message = "Marked as listened"
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "episode_#{@episode.id}_listened_button",
          partial: "episodes/listened_button",
          locals: { episode: @episode }
        )
      end
      format.html { redirect_to @episode, notice: message }
      format.json { render json: { listened: @episode.listened?, listened_at: @episode.listened_at }, status: :ok }
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
