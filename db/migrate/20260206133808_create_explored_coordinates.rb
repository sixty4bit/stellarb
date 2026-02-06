class CreateExploredCoordinates < ActiveRecord::Migration[8.1]
  def change
    create_table :explored_coordinates do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :x, null: false
      t.integer :y, null: false
      t.integer :z, null: false
      t.boolean :has_system, default: false, null: false

      t.timestamps
    end

    add_index :explored_coordinates, [:user_id, :x, :y, :z], unique: true
    add_index :explored_coordinates, [:x, :y, :z]
  end
end
