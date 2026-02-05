class AddFuelCapacityToShips < ActiveRecord::Migration[8.1]
  def change
    add_column :ships, :fuel_capacity, :decimal, default: 100.0, null: false
  end
end
