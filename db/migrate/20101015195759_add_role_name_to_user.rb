class AddRoleNameToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :role_name, :string
    User.reset_column_information
    User.update_all(:role_name => "admin")
  end

  def self.down
    remove_column :users, :role_name
  end
end
