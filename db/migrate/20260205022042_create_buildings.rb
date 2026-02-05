class CreateBuildings < ActiveRecord::Migration[8.1]
  def change
    create_table :buildings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :system, null: false, foreign_key: true
      t.string :name
      t.string :short_id
      t.string :race
      t.string :function
      t.integer :tier
      t.jsonb :building_attributes, default: {}
      t.string :status, default: 'active'

      t.timestamps
    end
    add_index :buildings, :short_id, unique: true
  end
end
