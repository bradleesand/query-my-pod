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

    # Fetch and parse RSS feed
    require "net/http"
    require "rexml/document"

    uri = URI.parse(task.url)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      task.failed!
      return
    end

    doc = REXML::Document.new(response.body)
    channel = doc.elements["rss/channel"]

    # Extract podcast GUID (use podcast:guid if available, otherwise generate from URL)
    podcast_guid = channel.elements["podcast:guid"]&.text || task.url

    # Check if podcast already exists by GUID or URL
    podcast = Podcast.find_by(guid: podcast_guid) || Podcast.find_by(rss_url: task.url)
    
    if podcast
      # Podcast already exists, just link to it
      task.update!(podcast: podcast)
      task.completed!
      return
    end

    # Create new podcast
    podcast = Podcast.new(guid: podcast_guid)
    
    # Update all fields from RSS spec
    podcast.assign_attributes(
      rss_url: task.url,
      title: channel.elements["title"]&.text,
      description: channel.elements["description"]&.text,
      link: channel.elements["link"]&.text,
      language: channel.elements["language"]&.text,
      category: channel.elements["itunes:category"]&.attributes&.[]("text"),
      explicit: parse_explicit(channel.elements["itunes:explicit"]&.text),
      image_url: channel.elements["itunes:image"]&.attributes&.[]("href"),
      author: channel.elements["itunes:author"]&.text,
      copywrite: channel.elements["copyright"]&.text
    )
    
    podcast.save!

    task.update!(podcast: podcast)
    task.completed!
  rescue => e
    task.failed! if task
    raise e
  end

  private

  def parse_explicit(value)
    return nil if value.nil?
    value.downcase == "true" || value.downcase == "yes"
  end
end
