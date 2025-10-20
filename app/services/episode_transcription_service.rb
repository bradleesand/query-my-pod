class EpisodeTranscriptionService
  include AudioFormat
  
  attr_reader :episode

  def initialize(episode)
    @episode = episode
  end

  def transcribe
    return if episode.transcription_completed?
    
    # Check if audio format is supported
    unless audio_format_supported?(episode.enclosure_type)
      Rails.logger.warn("Unsupported audio format for episode #{episode.id}: #{episode.enclosure_type}")
      episode.transcription_failed!
      return
    end
    
    episode.transcription_processing!
    
    begin
      # Step 1: Download audio if enabled
      audio_path = get_audio_file
      
      # Step 2: Trim ads if configured (future)
      # audio_path = AdTrimmerService.new(episode, audio_path).trim if should_trim_ads?
      
      # Step 3: Transcribe with Whisper
      transcript = transcribe_with_whisper(audio_path)
      
      # Step 4: Save transcript
      save_transcript(transcript)
      
      episode.transcription_completed!
    rescue => e
      Rails.logger.error("Failed to transcribe episode #{episode.id}: #{e.message}")
      episode.transcription_failed!
      false
    ensure
      # Clean up temporary files if we downloaded to temp
      cleanup_temp_file(audio_path) if audio_path && temp_file?(audio_path)
    end
  end

  private

  def get_audio_file
    # If local download is enabled and we have a local copy, use it
    if download_enabled? && episode.local_audio_path.present? && File.exist?(episode.local_audio_path)
      return episode.local_audio_path
    end
    
    # If local download is enabled, download it now
    if download_enabled?
      return EpisodeAudioDownloadService.new(episode).download
    end
    
    # Otherwise, download to temp file for transcription only
    download_to_temp
  end

  def download_enabled?
    ENV.fetch("DOWNLOAD_AUDIO", "false") == "true"
  end

  def download_to_temp
    require "open-uri"

    extension = file_extension_for_type(episode.enclosure_type)
    
    # This should not happen as we validate format in transcribe(), but guard anyway
    raise "Cannot determine file extension for temp file" if extension.nil?
    
    tempfile = Tempfile.new(["episode_audio", extension])
    tempfile.binmode
    
    URI.open(episode.enclosure_url, "rb") do |source|
      tempfile.write(source.read)
    end
    
    tempfile.close
    tempfile.path
  rescue OpenURI::HTTPError => e
    Rails.logger.error("HTTP error downloading episode #{episode.id} to temp: #{e.message} (URL: #{episode.enclosure_url})")
    tempfile&.close
    tempfile&.unlink
    raise "Failed to download audio: #{e.message}"
  rescue => e
    Rails.logger.error("Error downloading episode #{episode.id} to temp: #{e.class} - #{e.message} (URL: #{episode.enclosure_url})")
    tempfile&.close
    tempfile&.unlink
    raise
  end

  def temp_file?(path)
    path.start_with?(Dir.tmpdir)
  end

  def cleanup_temp_file(path)
    File.delete(path) if File.exist?(path)
  end

  def transcribe_with_whisper(audio_file_path)
    output_dir = "/tmp"
    result = `whisper "#{audio_file_path}" --model base --output_format json --output_dir #{output_dir} 2>&1`

    unless $?.success?
      raise "Whisper transcription failed: #{result}"
    end

    # Read the generated JSON file from the output directory
    # Whisper creates files named: basename_of_audio.json
    audio_basename = File.basename(audio_file_path, ".*")
    json_file = File.join(output_dir, "#{audio_basename}.json")

    unless File.exist?(json_file)
      raise "Whisper output file not found: #{json_file}"
    end

    transcript_json = File.read(json_file)
    File.delete(json_file)

    transcript_json
  end

  def save_transcript(content)
    episode.update!(generated_transcript: content)
  end
end
