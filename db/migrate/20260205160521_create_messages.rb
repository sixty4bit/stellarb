class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.string :from, null: false
      t.boolean :urgent, null: false, default: false
      t.datetime :read_at
      t.string :category
      t.string :uuid, limit: 36

      t.timestamps
    end

    add_index :messages, :uuid, unique: true
    add_index :messages, [:user_id, :read_at]
    add_index :messages, [:user_id, :urgent]
    add_index :messages, [:user_id, :category]
  end
end
