class CreateSystemVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :system_visits do |t|
      t.references :user, null: false, foreign_key: true
      t.references :system, null: false, foreign_key: true
      t.datetime :first_visited_at, null: false
      t.datetime :last_visited_at, null: false
      t.integer :visit_count, default: 1

      t.timestamps
    end

    add_index :system_visits, [:user_id, :system_id], unique: true
  end
end