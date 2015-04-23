class AddAttrTcpLenghtAndUdpLenghtInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :tcp_length, :integer, :default => 120
    add_column :configurations, :udp_length, :integer, :default => 200
  end

  def self.down
    remove_column :configurations, :tcp_length
    remove_column :configurations, :udp_length
  end
end
