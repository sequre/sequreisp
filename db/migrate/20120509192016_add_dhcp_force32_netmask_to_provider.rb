class AddDhcpForce32NetmaskToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :dhcp_force_32_netmask, :boolean, :default => true
  end

  def self.down
    remove_column :providers, :dhcp_force_32_netmask
  end
end
