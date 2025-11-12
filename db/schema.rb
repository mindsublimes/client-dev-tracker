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

ActiveRecord::Schema[7.1].define(version: 2025_11_12_081245) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agenda_items", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "assignee_id"
    t.string "title", null: false
    t.text "description"
    t.integer "work_stream", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "priority_level", default: 1, null: false
    t.integer "complexity", default: 3, null: false
    t.date "due_on"
    t.date "started_on"
    t.datetime "completed_at"
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.boolean "paid", default: false, null: false
    t.string "requested_by"
    t.string "requested_by_email"
    t.text "notes"
    t.integer "rank_score", default: 0, null: false
    t.jsonb "rank_breakdown", default: {}, null: false
    t.datetime "last_ranked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_agenda_items_on_assignee_id"
    t.index ["client_id"], name: "index_agenda_items_on_client_id"
    t.index ["due_on"], name: "index_agenda_items_on_due_on"
    t.index ["priority_level"], name: "index_agenda_items_on_priority_level"
    t.index ["rank_score"], name: "index_agenda_items_on_rank_score"
    t.index ["status"], name: "index_agenda_items_on_status"
    t.index ["work_stream"], name: "index_agenda_items_on_work_stream"
  end

  create_table "agenda_messages", force: :cascade do |t|
    t.bigint "agenda_item_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.integer "kind", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agenda_item_id"], name: "index_agenda_messages_on_agenda_item_id"
    t.index ["user_id"], name: "index_agenda_messages_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "contact_name"
    t.string "contact_email"
    t.integer "priority_level", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "timezone", default: "UTC", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_clients_on_code", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.integer "role", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agenda_items", "clients"
  add_foreign_key "agenda_items", "users", column: "assignee_id"
  add_foreign_key "agenda_messages", "agenda_items"
  add_foreign_key "agenda_messages", "users"
end
