class TranscriptChunk < ApplicationRecord
  belongs_to :episode
  has_one :podcast, through: :episode

  validates :text, presence: true
  validates :episode_id, presence: true

  # Vector similarity search
  has_neighbors :embedding, dimensions: 384

  # Parse JSON embedding for neighbor queries
  def embedding
    return nil unless self[:embedding].present?
    JSON.parse(self[:embedding])
  end

  # Convert array to JSON for storage
  def embedding=(value)
    self[:embedding] = value.is_a?(String) ? value : value.to_json
  end
end

