# == Schema Information
#
# Table name: episodes
#
#  id                   :integer          not null, primary key
#  podcast_id           :integer          not null
#  title                :text             not null
#  enclosure_length     :integer
#  enclosure_type       :text
#  enclosure_url        :text
#  guid                 :text             not null
#  link                 :text
#  pub_date             :datetime
#  description          :text
#  duration             :integer
#  image_url            :text
#  explicit             :boolean
#  transcript_url       :text
#  transcript_type      :text
#  episode_number       :integer
#  season_number        :integer
#  episode_type         :text
#  block                :boolean
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  generated_transcript :text
#  transcription_status :string
#  local_audio_path     :text
#  local_audio_size     :integer
#  local_audio_checksum :string
#  download_status      :string
#
# Indexes
#
#  index_episodes_on_podcast_id           (podcast_id)
#  index_episodes_on_podcast_id_and_guid  (podcast_id,guid)
#

require "test_helper"

class EpisodeTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
