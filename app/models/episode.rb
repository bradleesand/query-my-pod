class Episode < ApplicationRecord
  belongs_to :podcast

  after_create :enqueue_transcription_job

  enum :transcription_status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, prefix: :transcription

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

  private

  def enqueue_transcription_job
    # Only enqueue if there's an audio enclosure
    return unless enclosure_url.present?
    
    EpisodeTranscriptionJob.perform_later(id)
  end
end
