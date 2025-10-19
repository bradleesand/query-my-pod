class PodcastRssSyncService
  include RssParser
  
  attr_reader :podcast

  def initialize(podcast)
    @podcast = podcast
  end

  def sync
    doc = fetch_rss(podcast.rss_url)
    return false unless doc

    channel = doc.elements["rss/channel"]
    update_podcast_metadata(channel)
    import_new_episodes(doc)
    true
  rescue => e
    Rails.logger.error("Failed to sync podcast #{podcast.id}: #{e.message}")
    raise e
  end

  def import_new_episodes(doc)
    doc.elements.each("rss/channel/item") do |item|
      guid = item.elements["guid"]&.text
      next unless guid
      
      # Skip if episode already exists
      next if podcast.episodes.exists?(guid: guid)
      
      create_episode_from_item(item)
    end
  end

  private

  def update_podcast_metadata(channel)
    podcast.update!(podcast_attributes_from_channel(channel))
  end

  def create_episode_from_item(item)
    # Parse enclosure
    enclosure = item.elements["enclosure"]
    
    # Parse pub_date
    pub_date = begin
      Time.parse(item.elements["pubDate"]&.text) if item.elements["pubDate"]&.text
    rescue ArgumentError
      nil
    end
    
    podcast.episodes.create!(
      guid: item.elements["guid"]&.text,
      title: item.elements["title"]&.text,
      description: item.elements["description"]&.text,
      link: item.elements["link"]&.text,
      pub_date: pub_date,
      enclosure_url: enclosure&.attributes&.[]("url"),
      enclosure_type: enclosure&.attributes&.[]("type"),
      enclosure_length: enclosure&.attributes&.[]("length")&.to_i,
      duration: item.elements["itunes:duration"]&.text,
      image_url: item.elements["itunes:image"]&.attributes&.[]("href"),
      explicit: parse_explicit(item.elements["itunes:explicit"]&.text),
      episode_number: item.elements["itunes:episode"]&.text&.to_i,
      season_number: item.elements["itunes:season"]&.text&.to_i,
      episode_type: item.elements["itunes:episodeType"]&.text,
      transcript_url: item.elements["podcast:transcript"]&.attributes&.[]("url"),
      transcript_type: item.elements["podcast:transcript"]&.attributes&.[]("type")
    )
  end
end