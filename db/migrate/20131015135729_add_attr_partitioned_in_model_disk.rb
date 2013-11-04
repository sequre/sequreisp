class AddAttrPartitionedInModelDisk < ActiveRecord::Migration
  def self.up
    add_column :disks, :partitioned, :boolean, :default => false
  end

  def self.down
    remove_column :disks, :partitioned
  end
end
