class TranscriptChunk < ApplicationRecord
  belongs_to :episode
  has_one :podcast, through: :episode

  validates :text, presence: true
  validates :episode_id, presence: true

  # Enum for chunk types
  enum :chunk_type, {
    transcript: "transcript",
    title: "title",
    description: "description",
    advertisement: "advertisement"
  }

  # Vector similarity search
  has_neighbors :embedding, dimensions: 384

  # Scopes for filtering content
  scope :content, -> { where.not(chunk_type: "advertisement") }
  scope :ad_analyzed, -> { where.not(ad_confidence: nil) }
  scope :not_ad_analyzed, -> { where(ad_confidence: nil) }

  # Mark this chunk as an advertisement with confidence score
  # @param confidence [Float] 0.0-1.0, where higher = more confident it's an ad
  def mark_as_advertisement!(confidence)
    update!(
      chunk_type: :advertisement,
      ad_confidence: confidence
    )
  end

  # Mark this chunk as regular content (not an ad)
  # @param confidence [Float] 0.0-1.0, confidence this IS an ad (low values = likely content)
  def mark_as_content!(confidence)
    update!(
      chunk_type: :transcript,
      ad_confidence: confidence
    )
  end

  # Check if this chunk has been analyzed for ads
  def ad_analyzed?
    ad_confidence.present?
  end

  # Check if this chunk needs an embedding (content without embedding)
  def needs_embedding?
    !advertisement? && embedding.nil?
  end
end

