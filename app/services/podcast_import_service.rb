class PodcastImportService
  include RssParser
  
  attr_reader :url

  def initialize(url)
    @url = url
  end

  def import
    doc = fetch_rss(url)
    return nil unless doc

    channel = doc.elements["rss/channel"]
    podcast_guid = channel.elements["podcast:guid"]&.text || url

    # Check if podcast already exists by GUID or URL
    podcast = Podcast.find_by(guid: podcast_guid) || Podcast.find_by(rss_url: url)
    
    if podcast
      # Podcast already exists, refresh it
      PodcastRssSyncService.new(podcast).sync
      return podcast
    end

    # Create new podcast
    podcast = Podcast.create!(
      guid: podcast_guid,
      rss_url: url,
      **podcast_attributes_from_channel(channel)
    )
    
    # Import episodes
    PodcastRssSyncService.new(podcast).import_new_episodes(doc)
    
    podcast
  rescue => e
    Rails.logger.error("Failed to import podcast from #{url}: #{e.message}")
    raise e
  end
end