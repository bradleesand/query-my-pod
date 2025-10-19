module EpisodesHelper
  def download_status_color(status)
    case status
    when "completed"
      "success"
    when "downloading"
      "primary"
    when "failed"
      "danger"
    else
      "secondary"
    end
  end

  def transcription_status_color(status)
    case status
    when "completed"
      "success"
    when "processing"
      "primary"
    when "failed"
      "danger"
    else
      "secondary"
    end
  end
end
