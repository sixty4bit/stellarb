class AddTravelFieldsToShips < ActiveRecord::Migration[8.1]
  def change
    add_reference :ships, :destination_system, foreign_key: { to_table: :systems }
    add_column :ships, :arrival_at, :datetime
  end
end
