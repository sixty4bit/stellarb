class AddPriceSnapshotToSystemVisits < ActiveRecord::Migration[8.1]
  def change
    add_column :system_visits, :price_snapshot, :jsonb, default: {}
  end
end
