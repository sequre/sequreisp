class AddProxyArpProviderIdAndProxyArpGatewayToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :proxy_arp_provider_id, :integer
    add_column :contracts, :proxy_arp_gateway, :string
  end

  def self.down
    remove_column :contracts, :proxy_arp_gateway
    remove_column :contracts, :proxy_arp_provider_id
  end
end
