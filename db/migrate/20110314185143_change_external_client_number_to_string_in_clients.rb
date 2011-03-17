class ChangeExternalClientNumberToStringInClients < ActiveRecord::Migration
  def self.up
    change_column :clients, :external_client_number, :string
  end

  def self.down
    change_column :clients, :external_client_number, :integer
  end
end
