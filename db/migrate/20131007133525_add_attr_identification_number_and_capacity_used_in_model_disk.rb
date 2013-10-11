class AddAttrIdentificationNumberAndCapacityUsedInModelDisk < ActiveRecord::Migration
  def self.up
    add_column :disks, :capacity_used, :string, :default => "0"
    add_column :disks, :serial, :string
  end

  def self.down
    remove_column :disks, :capacity_used
    remove_column :disks, :serial
  end
end
