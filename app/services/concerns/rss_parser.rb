module RssParser
  private

  def fetch_rss(url)
    require "net/http"
    require "rexml/document"

    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)

    return nil unless response.is_a?(Net::HTTPSuccess)

    REXML::Document.new(response.body)
  end

  def podcast_attributes_from_channel(channel)
    {
      title: channel.elements["title"]&.text,
      description: channel.elements["description"]&.text,
      link: channel.elements["link"]&.text,
      language: channel.elements["language"]&.text,
      category: channel.elements["itunes:category"]&.attributes&.[]("text"),
      explicit: parse_explicit(channel.elements["itunes:explicit"]&.text),
      image_url: channel.elements["itunes:image"]&.attributes&.[]("href"),
      author: channel.elements["itunes:author"]&.text,
      copywrite: channel.elements["copyright"]&.text
    }
  end

  def parse_explicit(value)
    return nil if value.nil?
    value.downcase == "true" || value.downcase == "yes"
  end
end