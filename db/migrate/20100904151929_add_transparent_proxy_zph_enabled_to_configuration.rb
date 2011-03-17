class AddTransparentProxyZphEnabledToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :transparent_proxy_zph_enabled, :boolean, :default => true
  end

  def self.down
    remove_column :configurations, :transparent_proxy_zph_enabled
  end
end
