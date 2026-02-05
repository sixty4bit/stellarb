class AddIntentFieldsToShips < ActiveRecord::Migration[8.1]
  def change
    add_column :ships, :system_intent, :string
    add_column :ships, :defense_engaged_at, :datetime
  end
end
