class EpisodeProcessingJob < ApplicationJob
  queue_as :default

  # Available processing steps
  STEPS = {
    download: :download_audio,
    trim_ads: :trim_ads,
    transcribe: :transcribe_audio
  }.freeze

  # Default pipeline for full processing
  DEFAULT_PIPELINE = [:download, :trim_ads, :transcribe].freeze

  def perform(episode_id, remaining_steps = DEFAULT_PIPELINE)
    @episode = Episode.find(episode_id)
    
    # If no steps remaining, we're done
    return if remaining_steps.empty?
    
    # Get the next step
    current_step = remaining_steps.first
    next_steps = remaining_steps[1..]
    
    # Execute the current step
    success = execute_step(current_step)
    
    # If successful and there are more steps, enqueue the next job
    if success && next_steps.any?
      EpisodeProcessingJob.perform_later(@episode.id, next_steps)
    end
  end

  private

  def execute_step(step)
    step_method = STEPS[step]
    
    unless step_method
      Rails.logger.error("Unknown processing step: #{step} for episode #{@episode.id}")
      return false
    end
    
    send(step_method)
  rescue => e
    Rails.logger.error("Failed to execute step #{step} for episode #{@episode.id}: #{e.message}")
    false
  end

  def download_audio
    return true if @episode.download_completed?
    
    Rails.logger.info("Downloading audio for episode #{@episode.id}")
    result = EpisodeAudioDownloadService.new(@episode).download
    
    # Return true if download succeeded or was already completed
    result || @episode.download_completed?
  end

  def trim_ads
    # TODO: Implement when AdTrimmerService is ready
    # For now, just pass through
    Rails.logger.info("Ad trimming for episode #{@episode.id} (not yet implemented)")
    true
  end

  def transcribe_audio
    return true if @episode.transcription_completed?
    
    Rails.logger.info("Transcribing episode #{@episode.id}")
    EpisodeTranscriptionService.new(@episode).transcribe
    
    # Return true if transcription succeeded
    @episode.reload.transcription_completed?
  end
end
