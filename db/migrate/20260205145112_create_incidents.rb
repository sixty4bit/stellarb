# frozen_string_literal: true

class CreateIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incidents do |t|
      # Polymorphic association to Ship or Building
      t.references :asset, polymorphic: true, null: false

      # The NPC on duty when incident occurred (for service record)
      t.references :hired_recruit, foreign_key: true

      # Severity tier (1-5)
      t.integer :severity, null: false

      # Description of the incident (procedurally generated)
      t.text :description, null: false

      # Whether this is a pip infestation (requires physical presence to fix)
      t.boolean :is_pip_infestation, default: false, null: false

      # Resolution timestamp (null = unresolved)
      t.datetime :resolved_at

      # UUID for triple ID system
      t.string :uuid, limit: 36, index: { unique: true }

      t.timestamps
    end

    # Index for finding unresolved incidents on an asset
    add_index :incidents, [ :asset_type, :asset_id, :resolved_at ]

    # Index for finding pip infestations
    add_index :incidents, :is_pip_infestation, where: "is_pip_infestation = true AND resolved_at IS NULL"

    # Index for NPC service record queries
    add_index :incidents, [ :hired_recruit_id, :created_at ]
  end
end
