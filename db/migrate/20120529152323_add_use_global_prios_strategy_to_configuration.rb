class AddUseGlobalPriosStrategyToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :use_global_prios_strategy, :string, :default => 'provider'
  end

  def self.down
    remove_column :configurations, :use_global_prios_strategy
  end
end
