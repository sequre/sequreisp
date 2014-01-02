class AddAttrIsConnectedInModelContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :is_connected, :boolean, :default => false
  end

  def self.down
    remove_column :contracts, :is_connected
  end
end
