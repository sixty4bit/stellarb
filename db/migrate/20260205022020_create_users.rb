class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name
      t.string :short_id
      t.integer :level_tier, default: 1
      t.decimal :credits, default: 500.0
      t.datetime :last_sign_in_at
      t.integer :sign_in_count, default: 0

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :short_id, unique: true
  end
end
