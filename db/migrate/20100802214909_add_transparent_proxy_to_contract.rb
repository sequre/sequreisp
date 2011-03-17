class AddTransparentProxyToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :transparent_proxy, :boolean, :default => nil
    add_column :plans, :transparent_proxy, :boolean, :default => false 
    add_column :configurations, :transparent_proxy, :boolean, :default => true
  end

  def self.down
    remove_column :contracts, :transparent_proxy
    remove_column :plans, :transparent_proxy
    remove_column :configurations, :transparent_proxy
  end
end
