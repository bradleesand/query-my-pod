json.extract! episode, :id, :podcast_id, :title, :enclosure_length, :enclosure_type, :enclosure_url, :guid, :link, :pub_date, :description, :duration, :image_url, :explicit, :transcript_url, :transcript_type, :episode_number, :season_number, :episode_type, :block, :created_at, :updated_at
json.url episode_url(episode, format: :json)
