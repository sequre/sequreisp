class AddAttrCleanPartitionInModelDisk < ActiveRecord::Migration
  def self.up
    add_column :disks, :clean_partition, :boolean, :default => true
  end

  def self.down
    remove_column :disks, :clean_partition
  end
end
