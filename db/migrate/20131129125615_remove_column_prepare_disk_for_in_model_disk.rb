class RemoveColumnPrepareDiskForInModelDisk < ActiveRecord::Migration
  def self.up
    remove_column :disks, :prepare_disk_for
  end

  def self.down
    add_column :disks, :prepare_disk_for, :string
  end
end
