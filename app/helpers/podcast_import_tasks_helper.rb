module PodcastImportTasksHelper
  def status_class(task)
    case task.status
    when "pending"
      "alert-info"
    when "processing"
      "alert-warning"
    when "completed"
      "alert-success"
    when "failed"
      "alert-danger"
    else
      "alert-secondary"
    end
  end
end
