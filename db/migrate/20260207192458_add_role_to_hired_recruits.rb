class AddRoleToHiredRecruits < ActiveRecord::Migration[8.1]
  def change
    add_column :hired_recruits, :role, :string, default: "crew", null: false
    add_column :hired_recruits, :assistant_cooldown_until, :datetime
  end
end
