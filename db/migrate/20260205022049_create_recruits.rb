class CreateRecruits < ActiveRecord::Migration[8.1]
  def change
    create_table :recruits do |t|
      t.integer :level_tier
      t.string :race
      t.string :npc_class
      t.integer :skill
      t.jsonb :base_stats, default: {}
      t.jsonb :employment_history, default: []
      t.integer :chaos_factor
      t.datetime :available_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :recruits, :level_tier
    add_index :recruits, [:available_at, :expires_at]
  end
end
