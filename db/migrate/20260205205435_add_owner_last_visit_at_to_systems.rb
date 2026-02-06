class AddOwnerLastVisitAtToSystems < ActiveRecord::Migration[8.1]
  def change
    add_column :systems, :owner_last_visit_at, :datetime
    add_index :systems, :owner_last_visit_at, where: "owner_id IS NOT NULL"
  end
end
