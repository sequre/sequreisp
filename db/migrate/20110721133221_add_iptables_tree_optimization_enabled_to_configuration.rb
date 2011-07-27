class AddIptablesTreeOptimizationEnabledToConfiguration < ActiveRecord::Migration
  def self.up
    #optimze only on known 64bits machines
    optimize = begin
       `uname -m`.chomp == 'x86_64' ? true : false
    rescue
      false
    end
    add_column :configurations, :iptables_tree_optimization_enabled, :boolean, :default => optimize
  end

  def self.down
    remove_column :configurations, :iptables_tree_optimization_enabled
  end
end
