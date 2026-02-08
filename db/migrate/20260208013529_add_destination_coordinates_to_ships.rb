class AddDestinationCoordinatesToShips < ActiveRecord::Migration[8.1]
  def change
    add_column :ships, :destination_x, :integer
    add_column :ships, :destination_y, :integer
    add_column :ships, :destination_z, :integer
    add_column :ships, :travel_intent, :string
  end
end
