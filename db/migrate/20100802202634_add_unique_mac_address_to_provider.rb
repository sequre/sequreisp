class AddUniqueMacAddressToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :unique_mac_address, :boolean, :default => false
  end

  def self.down
    remove_column :providers, :unique_mac_address
  end
end
