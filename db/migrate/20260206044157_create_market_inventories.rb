class CreateMarketInventories < ActiveRecord::Migration[8.1]
  def change
    create_table :market_inventories do |t|
      t.references :system, null: false, foreign_key: true
      t.string :commodity, null: false
      t.integer :quantity, null: false, default: 0
      t.integer :max_quantity, null: false
      t.integer :restock_rate, null: false, default: 10

      t.timestamps
    end

    add_index :market_inventories, [:system_id, :commodity], unique: true
  end
end
