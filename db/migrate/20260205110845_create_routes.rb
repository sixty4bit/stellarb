class CreateRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :routes do |t|
      t.string :name
      t.string :short_id, null: false
      t.references :user, null: false, foreign_key: true
      t.references :ship, foreign_key: true
      t.string :status, default: "active"
      t.jsonb :stops, default: []
      t.integer :loop_count, default: 0
      t.decimal :total_profit, default: 0.0
      t.decimal :profit_per_hour, default: 0.0

      t.timestamps
    end

    add_index :routes, :short_id, unique: true
    add_index :routes, :status
  end
end