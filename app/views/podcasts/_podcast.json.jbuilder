json.extract! podcast, :id, :rss_url, :title, :description, :link, :language, :category, :explicit, :image_url, :guid, :author, :copywrite, :created_at, :updated_at
json.url podcast_url(podcast, format: :json)
