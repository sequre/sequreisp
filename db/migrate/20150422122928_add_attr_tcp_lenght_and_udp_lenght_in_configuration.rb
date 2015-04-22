class AddAttrTcpLenghtAndUdpLenghtInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :tcp_length, :integer, :default => 100
    add_column :configurations, :udp_length, :integer, :default => 100
  end

  def self.down
    remove_column :configurations, :tcp_length
    remove_column :configurations, :udp_length
  end
end
