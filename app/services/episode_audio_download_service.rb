class EpisodeAudioDownloadService
  include AudioFormat

  attr_reader :episode

  def initialize(episode)
    @episode = episode
  end

  def download
    return false unless should_download?

    # Check if audio format is supported
    unless audio_format_supported?(episode.enclosure_type)
      Rails.logger.warn("Unsupported audio format for episode #{episode.id}: #{episode.enclosure_type}")
      episode.download_failed!
      return false
    end

    # Check if we can determine the file extension
    if file_extension_for_type(episode.enclosure_type).nil?
      Rails.logger.error("Cannot determine file extension for episode #{episode.id}: mime_type=#{episode.enclosure_type.inspect}")
      episode.download_failed!
      return false
    end

    episode.download_downloading!

    begin
      # Download audio file to local storage
      local_path = download_to_storage

      # Calculate checksum
      checksum = calculate_checksum(local_path)

      # Update episode with file info (path is generated dynamically)
      episode.update!(
        local_audio_size: File.size(local_path),
        local_audio_checksum: checksum,
        download_status: :completed
      )

      local_path
    rescue => e
      Rails.logger.error("Failed to download audio for episode #{episode.id}: #{e.message}")
      episode.download_failed!
      false
    end
  end

  private

  def should_download?
    return false if episode.enclosure_url.blank?
    return false if episode.download_completed? && episode.local_audio_exists?
    true
  end

  def download_to_storage
    require "open-uri"

    destination_path = episode.audio_path

    # This should not happen as we check in download(), but guard anyway
    raise "Cannot determine file path: unknown or missing MIME type" if destination_path.nil?

    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(destination_path))

    # Download file with automatic redirect following
    URI.open(episode.enclosure_url, "rb") do |source|
      File.binwrite(destination_path, source.read)
    end

    destination_path
  rescue OpenURI::HTTPError => e
    Rails.logger.error("HTTP error downloading episode #{episode.id}: #{e.message} (URL: #{episode.enclosure_url})")
    raise "Failed to download audio: #{e.message}"
  rescue => e
    Rails.logger.error("Error downloading episode #{episode.id}: #{e.class} - #{e.message} (URL: #{episode.enclosure_url})")
    raise
  end

  def calculate_checksum(file_path)
    require "digest"
    Digest::SHA256.file(file_path).hexdigest
  end
end
