class AddWebInterfaceListenOnPortsToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :web_interface_listen_on_80, :boolean, :default => true
    add_column :configurations, :web_interface_listen_on_443, :boolean, :default => true
    add_column :configurations, :web_interface_listen_on_8080, :boolean, :default => true
  end

  def self.down
    remove_column :configurations, :web_interface_listen_on_8080
    remove_column :configurations, :web_interface_listen_on_443
    remove_column :configurations, :web_interface_listen_on_80
  end
end
