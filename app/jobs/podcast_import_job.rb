class PodcastImportJob < ApplicationJob
  queue_as :default
  
  # Prevent duplicate jobs for the same task ID
  # This ensures only one job runs per import task
  limits_concurrency to: 1, 
                     key: ->(podcast_import_task_id) { podcast_import_task_id },
                     duration: 30.minutes,
                     on_conflict: :discard

  def perform(podcast_import_task_id)
    task = PodcastImportTask.find(podcast_import_task_id)
    
    # Skip if already completed
    return if task.completed?
    
    task.processing!

    # Import the podcast
    podcast = PodcastImportService.new(task.url).import
    
    if podcast
      task.update!(podcast: podcast)
      task.completed!
    else
      task.failed!
    end
  rescue => e
    task.failed! if task
    raise e
  end
end
