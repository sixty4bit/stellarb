class CreateHiredRecruits < ActiveRecord::Migration[8.1]
  def change
    create_table :hired_recruits do |t|
      t.references :original_recruit, foreign_key: { to_table: :recruits }
      t.string :race
      t.string :npc_class
      t.integer :skill
      t.jsonb :stats, default: {}
      t.jsonb :employment_history, default: []
      t.integer :chaos_factor

      t.timestamps
    end
  end
end
