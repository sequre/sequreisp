class ChangeAttrTrafficPrioForBooleansAttrsInConfiguration < ActiveRecord::Migration
  def self.up
    remove_column :configurations, :traffic_prio
    add_column :configurations, :low_latency_for_tcp_length, :boolean, :default => true
    add_column :configurations, :low_latency_for_udp_length, :boolean, :default => true
    add_column :configurations, :low_latency_for_ssh, :boolean, :default => true
    add_column :configurations, :low_latency_for_dns, :boolean, :default => true
    add_column :configurations, :low_latency_for_icmp, :boolean, :default => true
    add_column :configurations, :low_latency_for_sip, :boolean, :default => true
  end

  def self.down
    add_column :configurations, :traffic_prio, :string, :default => ""
    remove_column :configurations, :low_latency_for_tcp_length
    remove_column :configurations, :low_latency_for_udp_length
    remove_column :configurations, :low_latency_for_ssh
    remove_column :configurations, :low_latency_for_dns
    remove_column :configurations, :low_latency_for_icmp
    remove_column :configurations, :low_latency_for_sip
  end
end
