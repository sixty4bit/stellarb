# frozen_string_literal: true

class AddDisabledToShipsAndBuildings < ActiveRecord::Migration[8.1]
  def change
    # Add disabled_at timestamp to track when asset was disabled by pip infestation
    # Using a timestamp instead of boolean to track when it happened
    add_column :ships, :disabled_at, :datetime
    add_column :buildings, :disabled_at, :datetime

    # Index for finding disabled assets
    add_index :ships, :disabled_at, where: "disabled_at IS NOT NULL"
    add_index :buildings, :disabled_at, where: "disabled_at IS NOT NULL"
  end
end
