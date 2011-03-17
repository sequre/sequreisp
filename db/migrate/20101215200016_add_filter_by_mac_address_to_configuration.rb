class AddFilterByMacAddressToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :filter_by_mac_address, :boolean, :default => true
  end

  def self.down
    remove_column :configurations, :filter_by_mac_address
  end
end
