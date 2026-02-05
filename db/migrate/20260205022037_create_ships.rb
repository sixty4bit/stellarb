class CreateShips < ActiveRecord::Migration[8.1]
  def change
    create_table :ships do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :short_id
      t.string :race
      t.string :hull_size
      t.integer :variant_idx
      t.jsonb :ship_attributes, default: {}
      t.references :current_system, foreign_key: { to_table: :systems }
      t.integer :location_x
      t.integer :location_y
      t.integer :location_z
      t.decimal :fuel, default: 0.0
      t.jsonb :cargo, default: {}
      t.string :status, default: 'docked'

      t.timestamps
    end
    add_index :ships, :short_id, unique: true
  end
end
