class RemoveAttrBurstInConfiguration < ActiveRecord::Migration
  def self.up
    remove_column :plans, :burst_down
    remove_column :plans, :burst_up
  end

  def self.down
    add_column :plans, :burst_down, :integer, :default => 0
    add_column :plans, :burst_up, :integer, :default => 0
  end
end
