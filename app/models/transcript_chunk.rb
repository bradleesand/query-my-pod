class TranscriptChunk < ApplicationRecord
  belongs_to :episode
  has_one :podcast, through: :episode

  validates :text, presence: true
  validates :episode_id, presence: true
end
