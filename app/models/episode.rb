# == Schema Information
#
# Table name: episodes
#
#  id                   :integer          not null, primary key
#  podcast_id           :integer          not null
#  title                :text             not null
#  enclosure_length     :integer
#  enclosure_type       :text
#  enclosure_url        :text
#  guid                 :text             not null
#  link                 :text
#  pub_date             :datetime
#  description          :text
#  duration             :integer
#  image_url            :text
#  explicit             :boolean
#  transcript_url       :text
#  transcript_type      :text
#  episode_number       :integer
#  season_number        :integer
#  episode_type         :text
#  block                :boolean
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  generated_transcript :text
#  transcription_status :string
#  local_audio_path     :text
#  local_audio_size     :integer
#  local_audio_checksum :string
#  download_status      :string
#
# Indexes
#
#  index_episodes_on_podcast_id           (podcast_id)
#  index_episodes_on_podcast_id_and_guid  (podcast_id,guid)
#

class Episode < ApplicationRecord
  belongs_to :podcast

  after_create :enqueue_background_jobs
  after_update_commit :broadcast_status_update

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

  def broadcast_status_update
    # Only broadcast if download_status or transcription_status changed
    return unless saved_change_to_download_status? || saved_change_to_transcription_status?
    
    broadcast_replace_to(
      "episode_#{id}_status",
      target: "episode_#{id}_status",
      partial: "episodes/status",
      locals: { episode: self }
    )
  end
end
