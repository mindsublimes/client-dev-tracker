class AddFigmaOauthToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :figma_access_token, :text
    add_column :users, :figma_refresh_token, :text
    add_column :users, :figma_token_expires_at, :datetime
  end
end
