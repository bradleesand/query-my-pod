class CreatePodcasts < ActiveRecord::Migration[8.0]
  def change
    create_table :podcasts do |t|
      t.text :rss_url
      t.text :title, null: false
      t.text :description
      t.text :link
      t.text :language
      t.text :category
      t.boolean :explicit
      t.text :image_url
      t.text :guid, null: false, index: {unique: true}
      t.text :author
      t.text :copywrite

      t.timestamps
    end
  end
end
