class AddAvoidNatAddressesToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :avoid_nat_addresses, :text
  end

  def self.down
    remove_column :providers, :avoid_nat_addresses
  end
end
