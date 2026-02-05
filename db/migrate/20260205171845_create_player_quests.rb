class CreatePlayerQuests < ActiveRecord::Migration[8.1]
  def change
    create_table :player_quests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :quest, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
