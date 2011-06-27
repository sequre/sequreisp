class AddUseGlobalPriosToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :use_global_prios, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :use_global_prios
  end
end
