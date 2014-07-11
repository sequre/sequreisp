class AddAttrsForBindDnsInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :dns_use_forwarders, :boolean, :default => false
    add_column :configurations, :dns_first_server, :string
    add_column :configurations, :dns_second_server, :string
    add_column :configurations, :dns_third_server, :string
  end

  def self.down
    remove_column :configurations, :dns_use_forwarders
    remove_column :configurations, :dns_first_server
    remove_column :configurations, :dns_second_server
    remove_column :configurations, :dns_third_server
  end
end
