class AddBurstToPlan < ActiveRecord::Migration
  def self.up
    add_column :plans, :burst_down, :integer, :default => 0
    add_column :plans, :burst_up, :integer, :default => 0
  end

  def self.down
    remove_column :plans, :burst_down
    remove_column :plans, :burst_up
  end
end
