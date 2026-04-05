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

ActiveRecord::Schema[8.1].define(version: 2026_04_04_143100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.integer "record_id"
    t.string "record_type"
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "consents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "granted"
    t.string "granted_to"
    t.bigint "patient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_id"], name: "index_consents_on_patient_id"
  end

  create_table "patients", force: :cascade do |t|
    t.integer "age", limit: 2
    t.datetime "created_at", null: false
    t.string "email"
    t.string "gender"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "phi_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "encrypted_data", null: false
    t.bigint "patient_id", null: false
    t.string "record_type", default: "general", null: false
    t.string "request_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_phi_records_on_created_by_id"
    t.index ["patient_id"], name: "index_phi_records_on_patient_id"
    t.index ["request_id"], name: "index_phi_records_on_request_id", unique: true
    t.index ["status"], name: "index_phi_records_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "consents", "patients"
  add_foreign_key "phi_records", "patients"
  add_foreign_key "phi_records", "users", column: "created_by_id"
end
