class ChangeHiringsAssignableNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :hirings, :assignable_id, true
    change_column_null :hirings, :assignable_type, true
  end
end
