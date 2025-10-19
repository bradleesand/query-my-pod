class AddLocalAudioToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :local_audio_path, :text
    add_column :episodes, :local_audio_size, :integer
    add_column :episodes, :local_audio_checksum, :string
    add_column :episodes, :download_status, :string
  end
end
