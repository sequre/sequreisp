class RemoveAndAddItemsToConfgiuration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :nf_conntrack_max, :integer
    add_column :configurations, :gc_thresh1, :integer
    add_column :configurations, :gc_thresh2, :integer
    add_column :configurations, :gc_thresh3, :integer
    remove_column :configurations, :rate_dfl_percent
    remove_column :configurations, :class_start
    remove_column :configurations, :rate_granted
  end

  def self.down
    remove_column :configurations, :nf_conntrack_max
    remove_column :configurations, :gc_thresh1
    remove_column :configurations, :gc_thresh2
    remove_column :configurations, :gc_thresh3
    add_column :configurations, :rate_dfl_percent, :string
    add_column :configurations, :class_start, :integer
    add_column :configurations, :rate_granted, :integer
  end
end
