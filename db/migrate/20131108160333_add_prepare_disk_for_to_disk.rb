class AddPrepareDiskForToDisk < ActiveRecord::Migration
  def self.up
    add_column :disks, :prepare_disk_for, :string
  end

  def self.down
    remove_column :disks, :prepare_disk_for
  end
end
