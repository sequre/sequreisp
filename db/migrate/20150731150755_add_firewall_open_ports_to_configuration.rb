class AddFirewallOpenPortsToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :firewall_enabled, :boolean, :default => false
    add_column :configurations, :firewall_open_tcp_ports, :string, :default => ""
    add_column :configurations, :firewall_open_udp_ports, :string, :default => ""
  end

  def self.down
    remove_column :configurations, :firewall_open_udp_ports
    remove_column :configurations, :firewall_open_tcp_ports
  end
end
