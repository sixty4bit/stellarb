class AddSpecializationToBuildings < ActiveRecord::Migration[8.1]
  def change
    add_column :buildings, :specialization, :string
  end
end
