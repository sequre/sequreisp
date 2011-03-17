class AddTransparentProxyNToMToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :transparent_proxy_n_to_m, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :transparent_proxy_n_to_m
  end
end
