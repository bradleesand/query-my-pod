class PodcastRefreshJob < ApplicationJob
  queue_as :default

  def perform(podcast_id)
    podcast = Podcast.find(podcast_id)
    PodcastRssSyncService.new(podcast).sync
  end
end
