class ChangeColumnNameMountCacheForNewDiskForCacheAdded < ActiveRecord::Migration
  def self.up
    rename_column :configurations, :mount_cache, :new_disk_for_cache_added
  end

  def self.down
    rename_column :configurations, :new_disk_for_cache_added, :mount_cache
  end
end
