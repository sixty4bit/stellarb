class CreateBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :system, null: false, foreign_key: true
      t.string :label

      t.timestamps
    end

    add_index :bookmarks, [:user_id, :system_id], unique: true
  end
end
