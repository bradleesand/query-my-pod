class EpisodeProcessingJob < ApplicationJob
  queue_as :default

  # Available processing steps
  STEPS = {
    download: :download_audio,
    trim_ads: :trim_ads,
    transcribe: :transcribe_audio,
    chunk_transcript: :chunk_transcript,
    detect_ads_in_transcript: :detect_ads_in_transcript,
    generate_embeddings: :generate_embeddings
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

  def chunk_transcript
    return true if @episode.transcript_chunks.any?

    Rails.logger.info("Chunking transcript for episode #{@episode.id}")
    TranscriptChunkingService.new(@episode).chunk
  end

  def detect_ads_in_transcript
    return true unless AppConfig.ad_detection_enabled?

    # Skip if no chunks exist yet
    return false if @episode.transcript_chunks.empty?

    # Skip if already processed (all transcript chunks have been analyzed)
    unanalyzed_chunks = @episode.transcript_chunks.transcript.not_ad_analyzed
    return true if unanalyzed_chunks.empty?

    Rails.logger.info("Detecting ads in transcript for episode #{@episode.id} (#{unanalyzed_chunks.count} unanalyzed chunks)")
    result = AdDetectionService.new.process_episode(@episode)

    Rails.logger.info("Ad detection complete for episode #{@episode.id}: #{result[:ads_detected]} ads found in #{result[:total_chunks]} chunks")
    true
  rescue => e
    Rails.logger.error("Failed to detect ads for episode #{@episode.id}: #{e.message}")
    false
  end

  def generate_embeddings
    # Only generate embeddings for content chunks (skip advertisements)
    # Note: When users reclassify ads → content via UI, we'll need to generate embeddings
    # for those chunks. See TranscriptChunk#mark_as_content! callback or UI controller.
    chunks_without_embeddings = @episode.transcript_chunks.content.where(embedding: nil)

    if chunks_without_embeddings.empty?
      Rails.logger.info("All content chunks already have embeddings for episode #{@episode.id}")
      return true
    end

    Rails.logger.info("Generating embeddings for #{chunks_without_embeddings.count} content chunks in episode #{@episode.id}")

    embedding_service = EmbeddingService.new
    chunks_without_embeddings.find_each do |chunk|
      embedding = embedding_service.generate(chunk.text)

      if embedding
        chunk.update!(embedding: embedding.to_json)
      else
        Rails.logger.error("Failed to generate embedding for chunk #{chunk.id}")
        return false
      end
    end

    Rails.logger.info("Successfully generated embeddings for episode #{@episode.id}")
    true
  rescue => e
    Rails.logger.error("Failed to generate embeddings for episode #{@episode.id}: #{e.message}")
    false
  end
end
