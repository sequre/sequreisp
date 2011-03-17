class AddQueuesToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :queue_down_prio, :float, :default => 0, :limit => 8
    add_column :contracts, :queue_up_prio, :float, :default => 0, :limit => 8
    add_column :contracts, :queue_down_dfl, :float, :default => 0, :limit => 8
    add_column :contracts, :queue_up_dfl, :float, :default => 0, :limit => 8
  end

  def self.down
    remove_column :contracts, :queue_up_dfl
    remove_column :contracts, :queue_down_dfl
    remove_column :contracts, :queue_up_prio
    remove_column :contracts, :queue_down_prio
  end
end
