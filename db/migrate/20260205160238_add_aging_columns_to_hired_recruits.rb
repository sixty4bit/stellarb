class AddAgingColumnsToHiredRecruits < ActiveRecord::Migration[8.1]
  def change
    add_column :hired_recruits, :age_days, :integer, default: 0, null: false
    add_column :hired_recruits, :lifespan_days, :integer
  end
end
