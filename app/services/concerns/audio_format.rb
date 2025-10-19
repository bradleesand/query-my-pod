module AudioFormat
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

  def audio_format_supported?(mime_type)
    return false if mime_type.blank?
    SUPPORTED_AUDIO_TYPES.include?(mime_type.downcase)
  end

  def file_extension_for_type(mime_type)
    return nil if mime_type.blank?
    
    case mime_type.downcase
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
      nil
    end
  end
end
