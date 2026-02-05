class AddProfileCompletedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :profile_completed_at, :datetime
  end
end
