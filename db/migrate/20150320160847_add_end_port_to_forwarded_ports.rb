class AddEndPortToForwardedPorts < ActiveRecord::Migration
  def self.up
    add_column :forwarded_ports, :end_port, :integer
  	rename_column :forwarded_ports, :public_port, :public_init_port
	end

  def self.down
    remove_column :forwarded_ports, :end_port
		rename_column :forwarded_ports, :public_init_port, :public_port
  end
end
