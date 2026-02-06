class AddSoundEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :sound_enabled, :boolean, default: true, null: false
  end
end
