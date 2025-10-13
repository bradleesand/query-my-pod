class CreatePodcastImportTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :podcast_import_tasks do |t|
      t.text :url
      t.text :status
      t.belongs_to :podcast, null: true, foreign_key: true

      t.timestamps
    end
  end
end
