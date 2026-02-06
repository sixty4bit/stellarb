# frozen_string_literal: true

class CreateMineralDiscoveries < ActiveRecord::Migration[8.0]
  def change
    create_table :mineral_discoveries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :discovered_in_system, foreign_key: { to_table: :systems }
      t.string :mineral_name, null: false
      t.datetime :discovered_at, null: false

      t.timestamps

      t.index [:user_id, :mineral_name], unique: true
    end
  end
end
