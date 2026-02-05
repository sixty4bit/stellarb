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

ActiveRecord::Schema[8.1].define(version: 2026_02_05_145127) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "buildings", force: :cascade do |t|
    t.jsonb "building_attributes", default: {}
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "function"
    t.string "name"
    t.string "race"
    t.string "short_id"
    t.string "status", default: "active"
    t.bigint "system_id", null: false
    t.integer "tier"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "uuid", limit: 36
    t.index ["disabled_at"], name: "index_buildings_on_disabled_at", where: "(disabled_at IS NOT NULL)"
    t.index ["short_id"], name: "index_buildings_on_short_id", unique: true
    t.index ["system_id"], name: "index_buildings_on_system_id"
    t.index ["user_id"], name: "index_buildings_on_user_id"
    t.index ["uuid"], name: "index_buildings_on_uuid", unique: true
  end

  create_table "flight_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "distance", precision: 10, scale: 2
    t.string "event_type", null: false
    t.bigint "from_system_id", null: false
    t.datetime "occurred_at", null: false
    t.bigint "ship_id", null: false
    t.bigint "to_system_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_type"], name: "index_flight_records_on_event_type"
    t.index ["from_system_id"], name: "index_flight_records_on_from_system_id"
    t.index ["occurred_at"], name: "index_flight_records_on_occurred_at"
    t.index ["ship_id", "occurred_at"], name: "index_flight_records_on_ship_id_and_occurred_at"
    t.index ["ship_id"], name: "index_flight_records_on_ship_id"
    t.index ["to_system_id"], name: "index_flight_records_on_to_system_id"
    t.index ["user_id", "occurred_at"], name: "index_flight_records_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_flight_records_on_user_id"
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
    t.string "uuid", limit: 36
    t.index ["original_recruit_id"], name: "index_hired_recruits_on_original_recruit_id"
    t.index ["uuid"], name: "index_hired_recruits_on_uuid", unique: true
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
    t.string "uuid", limit: 36
    t.decimal "wage"
    t.index ["assignable_type", "assignable_id"], name: "index_hirings_on_assignable"
    t.index ["hired_recruit_id"], name: "index_hirings_on_hired_recruit_id"
    t.index ["user_id"], name: "index_hirings_on_user_id"
    t.index ["uuid"], name: "index_hirings_on_uuid", unique: true
  end

  create_table "incidents", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.string "asset_type", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.bigint "hired_recruit_id"
    t.boolean "is_pip_infestation", default: false, null: false
    t.datetime "resolved_at"
    t.integer "severity", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36
    t.index ["asset_type", "asset_id", "resolved_at"], name: "index_incidents_on_asset_type_and_asset_id_and_resolved_at"
    t.index ["asset_type", "asset_id"], name: "index_incidents_on_asset"
    t.index ["hired_recruit_id", "created_at"], name: "index_incidents_on_hired_recruit_id_and_created_at"
    t.index ["hired_recruit_id"], name: "index_incidents_on_hired_recruit_id"
    t.index ["is_pip_infestation"], name: "index_incidents_on_is_pip_infestation", where: "((is_pip_infestation = true) AND (resolved_at IS NULL))"
    t.index ["uuid"], name: "index_incidents_on_uuid", unique: true
  end

  create_table "price_deltas", force: :cascade do |t|
    t.string "commodity", null: false
    t.datetime "created_at", null: false
    t.integer "delta_cents", default: 0, null: false
    t.bigint "system_id", null: false
    t.datetime "updated_at", null: false
    t.index ["system_id", "commodity"], name: "index_price_deltas_on_system_id_and_commodity", unique: true
    t.index ["system_id"], name: "index_price_deltas_on_system_id"
  end

  create_table "quest_progresses", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "quest_id", null: false
    t.datetime "started_at"
    t.string "status", default: "in_progress", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["quest_id"], name: "index_quest_progresses_on_quest_id"
    t.index ["user_id", "quest_id"], name: "index_quest_progresses_on_user_id_and_quest_id", unique: true
    t.index ["user_id"], name: "index_quest_progresses_on_user_id"
  end

  create_table "quests", force: :cascade do |t|
    t.text "context"
    t.datetime "created_at", null: false
    t.integer "credits_reward", default: 0
    t.string "galaxy", null: false
    t.json "mechanics_taught", default: []
    t.string "name", null: false
    t.integer "sequence", null: false
    t.string "short_id", null: false
    t.text "task"
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36
    t.index ["galaxy", "sequence"], name: "index_quests_on_galaxy_and_sequence", unique: true
    t.index ["short_id"], name: "index_quests_on_short_id", unique: true
    t.index ["uuid"], name: "index_quests_on_uuid", unique: true
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
    t.string "uuid", limit: 36
    t.index ["available_at", "expires_at"], name: "index_recruits_on_available_at_and_expires_at"
    t.index ["level_tier"], name: "index_recruits_on_level_tier"
    t.index ["uuid"], name: "index_recruits_on_uuid", unique: true
  end

  create_table "routes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "loop_count", default: 0
    t.string "name"
    t.decimal "profit_per_hour", default: "0.0"
    t.bigint "ship_id"
    t.string "short_id", null: false
    t.string "status", default: "active"
    t.jsonb "stops", default: []
    t.decimal "total_profit", default: "0.0"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "uuid", limit: 36
    t.index ["ship_id"], name: "index_routes_on_ship_id"
    t.index ["short_id"], name: "index_routes_on_short_id", unique: true
    t.index ["status"], name: "index_routes_on_status"
    t.index ["user_id"], name: "index_routes_on_user_id"
    t.index ["uuid"], name: "index_routes_on_uuid", unique: true
  end

  create_table "ships", force: :cascade do |t|
    t.datetime "arrival_at"
    t.jsonb "cargo", default: {}
    t.datetime "created_at", null: false
    t.bigint "current_system_id"
    t.datetime "defense_engaged_at"
    t.bigint "destination_system_id"
    t.datetime "disabled_at"
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
    t.string "system_intent"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "uuid", limit: 36
    t.integer "variant_idx"
    t.index ["current_system_id"], name: "index_ships_on_current_system_id"
    t.index ["destination_system_id"], name: "index_ships_on_destination_system_id"
    t.index ["disabled_at"], name: "index_ships_on_disabled_at", where: "(disabled_at IS NOT NULL)"
    t.index ["short_id"], name: "index_ships_on_short_id", unique: true
    t.index ["user_id"], name: "index_ships_on_user_id"
    t.index ["uuid"], name: "index_ships_on_uuid", unique: true
  end

  create_table "system_visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "first_visited_at", null: false
    t.datetime "last_visited_at", null: false
    t.bigint "system_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "visit_count", default: 1
    t.index ["system_id"], name: "index_system_visits_on_system_id"
    t.index ["user_id", "system_id"], name: "index_system_visits_on_user_id_and_system_id", unique: true
    t.index ["user_id"], name: "index_system_visits_on_user_id"
  end

  create_table "systems", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "discovered_by_id"
    t.datetime "discovery_date"
    t.string "name"
    t.bigint "owner_id"
    t.jsonb "properties"
    t.string "short_id"
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.index ["discovered_by_id"], name: "index_systems_on_discovered_by_id"
    t.index ["owner_id"], name: "index_systems_on_owner_id"
    t.index ["short_id"], name: "index_systems_on_short_id", unique: true
    t.index ["uuid"], name: "index_systems_on_uuid", unique: true
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
    t.string "uuid", limit: 36
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["short_id"], name: "index_users_on_short_id", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  create_table "warp_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "short_id", null: false
    t.string "status", default: "active"
    t.bigint "system_a_id", null: false
    t.bigint "system_b_id", null: false
    t.datetime "updated_at", null: false
    t.index ["short_id"], name: "index_warp_gates_on_short_id", unique: true
    t.index ["system_a_id"], name: "index_warp_gates_on_system_a_id"
    t.index ["system_b_id"], name: "index_warp_gates_on_system_b_id"
  end

  add_foreign_key "buildings", "systems"
  add_foreign_key "buildings", "users"
  add_foreign_key "flight_records", "ships"
  add_foreign_key "flight_records", "systems", column: "from_system_id"
  add_foreign_key "flight_records", "systems", column: "to_system_id"
  add_foreign_key "flight_records", "users"
  add_foreign_key "hired_recruits", "recruits", column: "original_recruit_id"
  add_foreign_key "hirings", "hired_recruits"
  add_foreign_key "hirings", "users"
  add_foreign_key "incidents", "hired_recruits"
  add_foreign_key "price_deltas", "systems"
  add_foreign_key "quest_progresses", "quests"
  add_foreign_key "quest_progresses", "users"
  add_foreign_key "routes", "ships"
  add_foreign_key "routes", "users"
  add_foreign_key "ships", "systems", column: "current_system_id"
  add_foreign_key "ships", "systems", column: "destination_system_id"
  add_foreign_key "ships", "users"
  add_foreign_key "system_visits", "systems"
  add_foreign_key "system_visits", "users"
  add_foreign_key "systems", "users", column: "discovered_by_id"
  add_foreign_key "systems", "users", column: "owner_id"
  add_foreign_key "warp_gates", "systems", column: "system_a_id"
  add_foreign_key "warp_gates", "systems", column: "system_b_id"
end
