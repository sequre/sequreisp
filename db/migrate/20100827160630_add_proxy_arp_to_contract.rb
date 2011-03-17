class AddProxyArpToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :proxy_arp, :boolean
  end

  def self.down
    remove_column :contracts, :proxy_arp
  end
end
