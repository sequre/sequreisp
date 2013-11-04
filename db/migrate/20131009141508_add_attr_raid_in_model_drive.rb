class AddAttrRaidInModelDrive < ActiveRecord::Migration
  def self.up
    add_column :disks, :raid, :string, :default => nil
  end

  def self.down
    remove_column :disks, :raid
  end
end
