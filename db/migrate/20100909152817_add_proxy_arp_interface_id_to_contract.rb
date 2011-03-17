class AddProxyArpInterfaceIdToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :proxy_arp_interface_id, :integer
  end

  def self.down
    remove_column :contracts, :proxy_arp_interface_id
  end
end
