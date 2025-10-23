# frozen_string_literal: true

# Central configuration for all application environment variables.
# This provides a single source of truth for ENV var access with type conversion and defaults.
module AppConfig
  class << self
    # =============================================================================
    # Ollama/LLM Configuration
    # =============================================================================

    def ollama_api_url
      ENV.fetch("OLLAMA_API_URL", "http://localhost:11434")
    end

    def ollama_model
      ENV.fetch("OLLAMA_MODEL", "qwen2.5:7b")
    end

    # =============================================================================
    # Search Configuration
    # =============================================================================

    def semantic_search_enabled?
      ENV.fetch("ENABLE_SEMANTIC_SEARCH", "true") == "true"
    end

    def search_context_chunks
      ENV.fetch("SEARCH_CONTEXT_CHUNKS", "10").to_i
    end

    # =============================================================================
    # Ad Detection Configuration
    # =============================================================================

    def ad_detection_enabled?
      ENV.fetch("ENABLE_AD_DETECTION", "true") == "true"
    end

    def ad_detection_threshold
      ENV.fetch("AD_DETECTION_THRESHOLD", "0.7").to_f
    end

    # =============================================================================
    # Transcription Configuration
    # =============================================================================

    def transcription_enabled?
      ENV.fetch("ENABLE_TRANSCRIPTION", "true") == "true"
    end

    def auto_transcribe?
      ENV.fetch("AUTO_TRANSCRIBE", "false") == "true"
    end

    # =============================================================================
    # Audio Download Configuration
    # =============================================================================

    def download_audio?
      ENV.fetch("DOWNLOAD_AUDIO", "true") == "true"
    end

    def auto_download_audio?
      ENV.fetch("AUTO_DOWNLOAD_AUDIO", "false") == "true"
    end

    # =============================================================================
    # Python/Embedding Configuration
    # =============================================================================

    def python_path
      ENV.fetch("PYTHON_PATH", "venv/bin/python3")
    end

    # =============================================================================
    # Server Configuration (for reference, but typically used directly in config files)
    # =============================================================================

    def rails_max_threads
      ENV.fetch("RAILS_MAX_THREADS", "5").to_i
    end

    def job_concurrency
      ENV.fetch("JOB_CONCURRENCY", "1").to_i
    end

    def port
      ENV.fetch("PORT", "3000").to_i
    end

    def rails_log_level
      ENV.fetch("RAILS_LOG_LEVEL", "info")
    end
  end
end
