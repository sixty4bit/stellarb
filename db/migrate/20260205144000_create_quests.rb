# frozen_string_literal: true

class CreateQuests < ActiveRecord::Migration[8.0]
  def change
    create_table :quests do |t|
      t.string :name, null: false
      t.string :short_id, null: false
      t.string :uuid, limit: 36
      t.string :galaxy, null: false
      t.integer :sequence, null: false
      t.text :context
      t.text :task
      t.json :mechanics_taught, default: []
      t.integer :credits_reward, default: 0

      t.timestamps

      t.index :short_id, unique: true
      t.index :uuid, unique: true
      t.index [:galaxy, :sequence], unique: true
    end

    create_table :player_quests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :quest, null: false, foreign_key: true
      t.string :status, null: false, default: "in_progress"
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps

      t.index [:user_id, :quest_id], unique: true
    end
  end
end
