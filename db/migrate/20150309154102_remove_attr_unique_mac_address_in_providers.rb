class RemoveAttrUniqueMacAddressInProviders < ActiveRecord::Migration
  def self.up
    remove_column :providers, :unique_mac_address
  end

  def self.down
    add_column :providers, :unique_mac_address, :boolean, :default => false
  end
end
