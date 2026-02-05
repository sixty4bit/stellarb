class CreateHirings < ActiveRecord::Migration[8.1]
  def change
    create_table :hirings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :hired_recruit, null: false, foreign_key: true
      t.string :custom_name
      t.references :assignable, polymorphic: true, null: false
      t.datetime :hired_at
      t.decimal :wage
      t.string :status
      t.datetime :terminated_at

      t.timestamps
    end
  end
end
