class AddAuthTokenToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :auth_token, :string
    add_column :users, :api_enabled, :boolean, :default => false
  end

  def self.down
    remove_column :users, :api_enabled
    remove_column :users, :auth_token
  end
end
