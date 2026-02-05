class CreatePriceDeltas < ActiveRecord::Migration[8.1]
  def change
    create_table :price_deltas do |t|
      t.references :system, null: false, foreign_key: true
      t.string :commodity, null: false
      t.integer :delta_cents, null: false, default: 0

      t.timestamps
    end

    add_index :price_deltas, [:system_id, :commodity], unique: true
  end
end
