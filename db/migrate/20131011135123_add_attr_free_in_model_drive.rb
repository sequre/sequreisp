class AddAttrFreeInModelDrive < ActiveRecord::Migration
  def self.up
    add_column :disks, :free, :boolean
  end

  def self.down
    remove_column :disks, :free
  end
end
