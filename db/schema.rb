# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_19_193149) do
  create_table "episodes", force: :cascade do |t|
    t.integer "podcast_id", null: false
    t.text "title", null: false
    t.integer "enclosure_length"
    t.text "enclosure_type"
    t.text "enclosure_url"
    t.text "guid", null: false
    t.text "link"
    t.datetime "pub_date"
    t.text "description"
    t.integer "duration"
    t.text "image_url"
    t.boolean "explicit"
    t.text "transcript_url"
    t.text "transcript_type"
    t.integer "episode_number"
    t.integer "season_number"
    t.text "episode_type"
    t.boolean "block"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "generated_transcript"
    t.string "transcription_status"
    t.text "local_audio_path"
    t.integer "local_audio_size"
    t.string "local_audio_checksum"
    t.string "download_status"
    t.index ["podcast_id", "guid"], name: "index_episodes_on_podcast_id_and_guid"
    t.index ["podcast_id"], name: "index_episodes_on_podcast_id"
  end

  create_table "podcast_import_tasks", force: :cascade do |t|
    t.text "url"
    t.text "status"
    t.integer "podcast_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["podcast_id"], name: "index_podcast_import_tasks_on_podcast_id"
  end

  create_table "podcasts", force: :cascade do |t|
    t.text "rss_url"
    t.text "title", null: false
    t.text "description"
    t.text "link"
    t.text "language"
    t.text "category"
    t.boolean "explicit"
    t.text "image_url"
    t.text "guid", null: false
    t.text "author"
    t.text "copywrite"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guid"], name: "index_podcasts_on_guid", unique: true
  end

  add_foreign_key "episodes", "podcasts"
  add_foreign_key "podcast_import_tasks", "podcasts"
end
