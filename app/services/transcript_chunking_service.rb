class TranscriptChunkingService
  def initialize(episode)
    @episode = episode
  end

  def chunk
    unless @episode.transcription_completed?
      Rails.logger.warn("Episode #{@episode.id} transcription not completed, cannot chunk")
      return false
    end

    unless @episode.generated_transcript.present?
      Rails.logger.error("No transcript data found for episode #{@episode.id}")
      return false
    end

    # Skip if already chunked
    if @episode.transcript_chunks.any?
      Rails.logger.info("Episode #{@episode.id} already chunked (#{@episode.transcript_chunks.count} chunks)")
      return true
    end

    begin
      chunks_created = 0

      # Create title chunk
      if @episode.title.present?
        TranscriptChunk.create!(
          episode: @episode,
          text: @episode.title,
          start_time: nil,
          end_time: nil,
          chunk_index: -2, # Negative index to indicate metadata chunks
          chunk_type: "title"
        )
        chunks_created += 1
      end

      # Create description chunk
      if @episode.description.present?
        TranscriptChunk.create!(
          episode: @episode,
          text: @episode.description,
          start_time: nil,
          end_time: nil,
          chunk_index: -1, # Negative index to indicate metadata chunks
          chunk_type: "description"
        )
        chunks_created += 1
      end

      # Create transcript chunks from segments
      transcript_data = @episode.transcript_content
      segments = transcript_data["segments"]

      unless segments.is_a?(Array)
        Rails.logger.error("Invalid transcript format for episode #{@episode.id}: missing segments array")
        return false
      end

      segments.each_with_index do |segment, index|
        TranscriptChunk.create!(
          episode: @episode,
          text: segment["text"],
          start_time: segment["start"],
          end_time: segment["end"],
          chunk_index: index,
          chunk_type: "transcript"
        )
        chunks_created += 1
      end

      Rails.logger.info("Created #{chunks_created} chunks for episode #{@episode.id}")
      true
    rescue => e
      Rails.logger.error("Failed to chunk transcript for episode #{@episode.id}: #{e.message}")
      false
    end
  end
end