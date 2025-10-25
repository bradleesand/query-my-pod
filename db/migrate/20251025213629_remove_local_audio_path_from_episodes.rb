class RemoveLocalAudioPathFromEpisodes < ActiveRecord::Migration[8.0]
  def change
    remove_column :episodes, :local_audio_path, :text
  end
end
