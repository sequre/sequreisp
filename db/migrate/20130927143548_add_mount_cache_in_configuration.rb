class AddMountCacheInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :mount_cache, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :mount_cache
  end
end
