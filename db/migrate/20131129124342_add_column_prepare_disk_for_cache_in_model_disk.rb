class AddColumnPrepareDiskForCacheInModelDisk < ActiveRecord::Migration
  def self.up
    add_column :disks, :prepare_disk_for_cache, :boolean, :default => false
  end

  def self.down
    remove_column :disks, :prepare_disk_for_cache
  end
end
