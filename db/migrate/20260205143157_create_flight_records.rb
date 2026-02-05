class CreateFlightRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :flight_records do |t|
      t.references :ship, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :from_system, null: false, foreign_key: { to_table: :systems }
      t.references :to_system, null: false, foreign_key: { to_table: :systems }
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.decimal :distance, precision: 10, scale: 2

      t.timestamps
    end

    add_index :flight_records, :event_type
    add_index :flight_records, :occurred_at
    add_index :flight_records, [:user_id, :occurred_at]
    add_index :flight_records, [:ship_id, :occurred_at]
  end
end
