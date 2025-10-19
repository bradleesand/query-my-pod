class RefreshAllPodcastsJob < ApplicationJob
  queue_as :default

  def perform
    Podcast.find_each do |podcast|
      PodcastRefreshJob.perform_later(podcast.id)
    end
  end
end
