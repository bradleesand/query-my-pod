class CreateEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :episodes do |t|
      t.belongs_to :podcast, null: false, foreign_key: true
      t.text :title, null: false
      t.integer :enclosure_length
      t.text :enclosure_type
      t.text :enclosure_url
      t.text :guid, null: false
      t.text :link
      t.datetime :pub_date
      t.text :description
      t.integer :duration
      t.text :image_url
      t.boolean :explicit
      t.text :transcript_url
      t.text :transcript_type
      t.integer :episode_number
      t.integer :season_number
      t.text :episode_type
      t.boolean :block

      t.timestamps

      t.index [:podcast_id, :guid]
    end
  end
end
