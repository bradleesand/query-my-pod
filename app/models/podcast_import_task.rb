class PodcastImportTask < ApplicationRecord
  include ActionView::RecordIdentifier
  
  belongs_to :podcast, optional: true

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, default: :pending

  before_create :check_existing_podcast
  after_create :enqueue_import_job, unless: :completed?
  after_update_commit :broadcast_update

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  private

  def check_existing_podcast
    # Check if a podcast with this URL already exists
    existing_podcast = Podcast.find_by(rss_url: url)
    
    if existing_podcast
      self.podcast = existing_podcast
      self.status = :completed
    end
  end

  def enqueue_import_job
    PodcastImportJob.perform_later(id)
  end

  def broadcast_update
    broadcast_replace_to "podcast_imports",
                         target: dom_id(self),
                         partial: "podcast_import_tasks/import_task",
                         locals: { import_task: self }
  end
end
