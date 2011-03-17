class AddExternalClientNumberToClient < ActiveRecord::Migration
  def self.up
    add_column :clients, :external_client_number, :integer
  end

  def self.down
    remove_column :clients, :external_client_number
  end
end
