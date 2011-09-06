class AddTransparentProxyWindowsUpdateHackToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :transparent_proxy_windows_update_hack, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :transparent_proxy_windows_update_hack
  end
end
