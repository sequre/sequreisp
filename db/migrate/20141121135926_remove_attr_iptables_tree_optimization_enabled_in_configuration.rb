class RemoveAttrIptablesTreeOptimizationEnabledInConfiguration < ActiveRecord::Migration
  def self.up
    remove_column :configurations, :iptables_tree_optimization_enabled
  end

  def self.down
    add_column :configurations, :iptables_tree_optimization_enabled, :boolean, :default => false
  end
end
