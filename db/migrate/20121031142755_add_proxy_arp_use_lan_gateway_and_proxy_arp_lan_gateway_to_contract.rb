class AddProxyArpUseLanGatewayAndProxyArpLanGatewayToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :proxy_arp_use_lan_gateway, :boolean, :default => false
    add_column :contracts, :proxy_arp_lan_gateway, :string
  end

  def self.down
    remove_column :contracts, :proxy_arp_lan_gateway
    remove_column :contracts, :proxy_arp_use_lan_gateway
  end
end
