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

ActiveRecord::Schema[8.1].define(version: 2026_02_05_022059) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "buildings", force: :cascade do |t|
    t.jsonb "building_attributes", default: {}
    t.datetime "created_at", null: false
    t.string "function"
    t.string "name"
    t.string "race"
    t.string "short_id"
    t.string "status", default: "active"
    t.bigint "system_id", null: false
    t.integer "tier"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["short_id"], name: "index_buildings_on_short_id", unique: true
    t.index ["system_id"], name: "index_buildings_on_system_id"
    t.index ["user_id"], name: "index_buildings_on_user_id"
  end

  create_table "hired_recruits", force: :cascade do |t|
    t.integer "chaos_factor"
    t.datetime "created_at", null: false
    t.jsonb "employment_history", default: []
    t.string "npc_class"
    t.bigint "original_recruit_id"
    t.string "race"
    t.integer "skill"
    t.jsonb "stats", default: {}
    t.datetime "updated_at", null: false
    t.index ["original_recruit_id"], name: "index_hired_recruits_on_original_recruit_id"
  end

  create_table "hirings", force: :cascade do |t|
    t.bigint "assignable_id", null: false
    t.string "assignable_type", null: false
    t.datetime "created_at", null: false
    t.string "custom_name"
    t.datetime "hired_at"
    t.bigint "hired_recruit_id", null: false
    t.string "status"
    t.datetime "terminated_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "wage"
    t.index ["assignable_type", "assignable_id"], name: "index_hirings_on_assignable"
    t.index ["hired_recruit_id"], name: "index_hirings_on_hired_recruit_id"
    t.index ["user_id"], name: "index_hirings_on_user_id"
  end

  create_table "recruits", force: :cascade do |t|
    t.datetime "available_at"
    t.jsonb "base_stats", default: {}
    t.integer "chaos_factor"
    t.datetime "created_at", null: false
    t.jsonb "employment_history", default: []
    t.datetime "expires_at"
    t.integer "level_tier"
    t.string "npc_class"
    t.string "race"
    t.integer "skill"
    t.datetime "updated_at", null: false
    t.index ["available_at", "expires_at"], name: "index_recruits_on_available_at_and_expires_at"
    t.index ["level_tier"], name: "index_recruits_on_level_tier"
  end

  create_table "ships", force: :cascade do |t|
    t.jsonb "cargo", default: {}
    t.datetime "created_at", null: false
    t.bigint "current_system_id"
    t.decimal "fuel", default: "0.0"
    t.string "hull_size"
    t.integer "location_x"
    t.integer "location_y"
    t.integer "location_z"
    t.string "name"
    t.string "race"
    t.jsonb "ship_attributes", default: {}
    t.string "short_id"
    t.string "status", default: "docked"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "variant_idx"
    t.index ["current_system_id"], name: "index_ships_on_current_system_id"
    t.index ["short_id"], name: "index_ships_on_short_id", unique: true
    t.index ["user_id"], name: "index_ships_on_user_id"
  end

  create_table "systems", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "discovered_by_id"
    t.datetime "discovery_date"
    t.string "name"
    t.jsonb "properties"
    t.string "short_id"
    t.datetime "updated_at", null: false
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.index ["discovered_by_id"], name: "index_systems_on_discovered_by_id"
    t.index ["short_id"], name: "index_systems_on_short_id", unique: true
    t.index ["x", "y", "z"], name: "index_systems_on_x_and_y_and_z", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "credits", default: "500.0"
    t.string "email"
    t.datetime "last_sign_in_at"
    t.integer "level_tier", default: 1
    t.string "name"
    t.string "short_id"
    t.integer "sign_in_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["short_id"], name: "index_users_on_short_id", unique: true
  end

  add_foreign_key "buildings", "systems"
  add_foreign_key "buildings", "users"
  add_foreign_key "hired_recruits", "recruits", column: "original_recruit_id"
  add_foreign_key "hirings", "hired_recruits"
  add_foreign_key "hirings", "users"
  add_foreign_key "ships", "systems", column: "current_system_id"
  add_foreign_key "ships", "users"
  add_foreign_key "systems", "users", column: "discovered_by_id"
end
