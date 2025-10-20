class CreateTranscriptChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :transcript_chunks do |t|
      t.references :episode, null: false, foreign_key: true
      t.text :text, null: false
      t.text :embedding
      t.float :start_time
      t.float :end_time
      t.integer :chunk_index
      t.string :chunk_type, default: "transcript"

      t.timestamps
    end

    add_index :transcript_chunks, :start_time
    add_index :transcript_chunks, :chunk_type
  end
end
