class RemoveForwardPortsFromContract < ActiveRecord::Migration
  def self.up
    remove_column :contracts, :forward_ports
  end

  def self.down
    add_column :contracts, :forward_ports, :string  
  end
end
