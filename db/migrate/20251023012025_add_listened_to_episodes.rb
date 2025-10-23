class AddListenedToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :listened_at, :datetime
    add_index :episodes, :listened_at
  end
end
