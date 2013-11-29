class DeleteColumnPartitionedAndCleanPartitionInModelDisk < ActiveRecord::Migration
  def self.up
    remove_column :disks, :clean_partition
    remove_column :disks, :partitioned
  end

  def self.down
    add_column :disks, :clean_partition, :boolean, :default => true
    add_column :disks, :partitioned, :boolean, :default => false
  end
end
