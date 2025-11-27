class AddClientRoleToUsers < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:users, :client_role)
      add_column :users, :client_role, :integer, default: 0, null: false
    else
      # Column exists, just ensure it has the right default
      change_column_default :users, :client_role, 0
      change_column_null :users, :client_role, false
    end
  end
end
