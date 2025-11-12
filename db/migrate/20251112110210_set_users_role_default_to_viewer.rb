class SetUsersRoleDefaultToViewer < ActiveRecord::Migration[7.1]
  def up
    change_column_default :users, :role, 4
  end

  def down
    change_column_default :users, :role, 0
  end
end
