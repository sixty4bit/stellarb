class AddTutorialPhaseToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tutorial_phase, :string, default: "cradle", null: false
    add_index :users, :tutorial_phase
  end
end
