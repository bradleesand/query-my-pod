class AddGeneratedTranscriptToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :generated_transcript, :text
    add_column :episodes, :transcription_status, :string
  end
end
