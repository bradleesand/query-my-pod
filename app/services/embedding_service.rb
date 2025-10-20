class EmbeddingService
  PYTHON_PATH = ENV.fetch("PYTHON_PATH", "venv/bin/python3")
  SCRIPT_PATH = Rails.root.join("scripts", "generate_embedding.py")

  def initialize
    validate_dependencies!
  end

  def generate(text)
    return nil if text.blank?

    # Call Python script and parse result
    result = call_python_script(text)
    JSON.parse(result)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse embedding JSON: #{e.message}")
    nil
  rescue => e
    Rails.logger.error("Failed to generate embedding: #{e.message}")
    nil
  end

  # Generate embeddings for multiple texts (more efficient)
  def generate_batch(texts)
    texts.map { |text| generate(text) }
  end

  private

  def call_python_script(text)
    # Use a temporary file to avoid shell escaping issues
    require 'tempfile'

    Tempfile.create(['embedding_input', '.txt']) do |tmpfile|
      tmpfile.write(text)
      tmpfile.flush

      # Call Python script with stdin from temp file
      result = `#{PYTHON_PATH} #{SCRIPT_PATH} < #{tmpfile.path} 2>&1`

      unless $?.success?
        raise "Python script failed: #{result}"
      end

      result
    end
  end

  def validate_dependencies!
    unless File.exist?(SCRIPT_PATH)
      raise "Embedding script not found at #{SCRIPT_PATH}"
    end

    unless File.exist?(PYTHON_PATH)
      raise "Python not found at #{PYTHON_PATH}. Set PYTHON_PATH environment variable."
    end
  end
end