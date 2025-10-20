class AddIndexToTranscriptChunksEpisodeIdAndStartTime < ActiveRecord::Migration[8.0]
  def change
    add_index :transcript_chunks, [:episode_id, :start_time]
  end
end
