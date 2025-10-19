class Episode < ApplicationRecord
  belongs_to :podcast

  after_create :enqueue_background_jobs

  enum :transcription_status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, prefix: :transcription

  enum :download_status, {
    pending: "pending",
    downloading: "downloading",
    completed: "completed",
    failed: "failed"
  }, prefix: :download

  def transcript_file_path
    Rails.root.join("storage", "transcripts", "#{id}.json")
  end

  def transcript_content
    return nil unless transcription_completed? && transcript_file_path.exist?
    JSON.parse(File.read(transcript_file_path))
  end
  
  def transcript_text
    return nil unless transcript_content
    transcript_content["text"]
  end

  def audio_url
    # Use local audio if available, otherwise original URL
    if local_audio_path.present? && File.exist?(local_audio_path)
      "/episodes/#{id}/audio"
    else
      enclosure_url
    end
  end

  private

  def enqueue_background_jobs
    return unless enclosure_url.present?
    
    # Build the processing pipeline based on env vars
    steps = []
    
    if ENV.fetch("AUTO_DOWNLOAD_AUDIO", "false") == "true"
      steps << :download
    end
    
    # Always include transcription if enabled
    # (it will handle its own downloading if AUTO_DOWNLOAD_AUDIO is false)
    if ENV.fetch("AUTO_TRANSCRIBE", "false") == "true"
      steps << :transcribe
    end
    
    # Enqueue the processing job with the appropriate steps
    if steps.any?
      EpisodeProcessingJob.perform_later(id, steps)
    end
  end
end
