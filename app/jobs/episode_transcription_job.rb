class EpisodeTranscriptionJob < ApplicationJob
  queue_as :default

  # Audio formats supported by Whisper
  SUPPORTED_AUDIO_TYPES = %w[
    audio/mpeg
    audio/mp3
    audio/mp4
    audio/m4a
    audio/x-m4a
    audio/wav
    audio/wave
    audio/x-wav
    audio/flac
    audio/ogg
    audio/webm
  ].freeze

  def perform(episode_id)
    episode = Episode.find(episode_id)
    
    # Skip if already transcribed or no audio
    return if episode.transcription_completed? || episode.enclosure_url.blank?
    
    # Check if audio format is supported
    unless audio_format_supported?(episode.enclosure_type)
      Rails.logger.warn("Unsupported audio format for episode #{episode_id}: #{episode.enclosure_type}")
      return
    end
    
    episode.update!(transcription_status: :processing)

    # Download audio file
    audio_file = download_audio(episode.enclosure_url, episode.enclosure_type)
    
    begin
      # Run Whisper transcription
      transcript = transcribe_audio(audio_file)
      
      # Save transcript to file
      save_transcript(episode, transcript)
      
      episode.update!(transcription_status: :completed)
    ensure
      # Clean up downloaded audio file
      File.delete(audio_file) if File.exist?(audio_file)
    end
  rescue => e
    episode.update!(transcription_status: :failed) if episode
    Rails.logger.error("Failed to transcribe episode #{episode_id}: #{e.message}")
    raise e
  end

  private

  def audio_format_supported?(enclosure_type)
    return false if enclosure_type.blank?
    SUPPORTED_AUDIO_TYPES.include?(enclosure_type.downcase)
  end

  def download_audio(url, enclosure_type)
    require "net/http"
    require "tempfile"

    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Failed to download audio: #{response.code}"
    end

    # Determine file extension from MIME type
    extension = file_extension_for_type(enclosure_type)
    
    # Save to temporary file with correct extension
    tempfile = Tempfile.new(["episode_audio", extension])
    tempfile.binmode
    tempfile.write(response.body)
    tempfile.close
    
    tempfile.path
  end

  def file_extension_for_type(mime_type)
    case mime_type&.downcase
    when "audio/mpeg", "audio/mp3"
      ".mp3"
    when "audio/mp4", "audio/m4a", "audio/x-m4a"
      ".m4a"
    when "audio/wav", "audio/wave", "audio/x-wav"
      ".wav"
    when "audio/flac"
      ".flac"
    when "audio/ogg"
      ".ogg"
    when "audio/webm"
      ".webm"
    else
      ".mp3"  # Default fallback
    end
  end

  def transcribe_audio(audio_file_path)
    # Call Whisper via command line
    # You'll need to have whisper installed: pip install openai-whisper
    result = `whisper "#{audio_file_path}" --model base --output_format json --output_dir /tmp 2>&1`
    
    unless $?.success?
      raise "Whisper transcription failed: #{result}"
    end
    
    # Read the generated JSON file
    json_file = audio_file_path.gsub(/\.[^.]+$/, ".json")
    transcript_json = File.read(json_file)
    File.delete(json_file) if File.exist?(json_file)
    
    transcript_json
  end

  def save_transcript(episode, content)
    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(episode.transcript_file_path))
    
    # Write transcript to file
    File.write(episode.transcript_file_path, content)
  end
end
