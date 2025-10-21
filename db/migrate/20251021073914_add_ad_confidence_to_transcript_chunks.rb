class AddAdConfidenceToTranscriptChunks < ActiveRecord::Migration[8.0]
  def change
    add_column :transcript_chunks, :ad_confidence, :float
  end
end
