class CreateSystems < ActiveRecord::Migration[8.1]
  def change
    create_table :systems do |t|
      t.integer :x
      t.integer :y
      t.integer :z
      t.string :name
      t.string :short_id
      t.references :discovered_by, foreign_key: { to_table: :users }
      t.datetime :discovery_date
      t.jsonb :properties

      t.timestamps
    end
    add_index :systems, :short_id, unique: true
    add_index :systems, [:x, :y, :z], unique: true
  end
end
