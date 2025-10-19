class PodcastImportTasksController < ApplicationController
  def new
    @podcast_import_task = PodcastImportTask.new
  end

  def create
    @podcast_import_task = PodcastImportTask.new(podcast_import_task_params)

    respond_to do |format|
      if @podcast_import_task.save
        # Broadcast the new pending import to the index page
        @podcast_import_task.broadcast_prepend_to "podcast_imports",
                                                   target: "pending_imports",
                                                   partial: "podcast_import_tasks/import_task",
                                                   locals: { import_task: @podcast_import_task }
        
        format.html { redirect_to podcasts_path, notice: "Podcast import started! It will appear shortly." }
        format.turbo_stream
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def podcast_import_task_params
    params.require(:podcast_import_task).permit(:url)
  end
end
