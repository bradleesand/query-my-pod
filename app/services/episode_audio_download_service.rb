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
      
      # Update episode with local file info
      episode.update!(
        local_audio_path: local_path,
        local_audio_size: File.size(local_path),
        local_audio_checksum: checksum,
        download_status: :completed
      )
      
      local_path
    rescue => e
      episode.download_failed!
      Rails.logger.error("Failed to download audio for episode #{episode.id}: #{e.message}")
      raise e
    end
  end

  def local_audio_path
    return episode.local_audio_path if episode.local_audio_path.present?
    
    storage_dir = Rails.root.join("storage", "episodes", episode.podcast_id.to_s)
    FileUtils.mkdir_p(storage_dir)
    
    extension = file_extension_for_type(episode.enclosure_type)
    return nil if extension.nil?
    
    storage_dir.join("#{episode.id}#{extension}").to_s
  end

  private

  def should_download?
    return false if episode.enclosure_url.blank?
    return false if episode.download_completed? && File.exist?(episode.local_audio_path.to_s)
    true
  end

  def download_to_storage
    require "net/http"
    require "uri"

    uri = URI.parse(episode.enclosure_url)
    destination_path = local_audio_path
    
    # This should not happen as we check in download(), but guard anyway
    raise "Cannot determine file path: unknown or missing MIME type" if destination_path.nil?

    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(destination_path))

    # Download file
    File.open(destination_path, "wb") do |file|
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        
        http.request(request) do |response|
          unless response.is_a?(Net::HTTPSuccess)
            raise "Failed to download audio: #{response.code}"
          end
          
          response.read_body do |chunk|
            file.write(chunk)
          end
        end
      end
    end

    destination_path
  end

  def calculate_checksum(file_path)
    require "digest"
    Digest::SHA256.file(file_path).hexdigest
  end
end
