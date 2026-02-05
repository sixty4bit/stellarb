class CreateWarpGates < ActiveRecord::Migration[8.1]
  def change
    create_table :warp_gates do |t|
      t.references :system_a, null: false, foreign_key: { to_table: :systems }
      t.references :system_b, null: false, foreign_key: { to_table: :systems }
      t.string :name
      t.string :status, default: "active"
      t.string :short_id, null: false

      t.timestamps
    end

    add_index :warp_gates, :short_id, unique: true
  end
end
