class RemoveHtbObsoleteParamsFromConfiguration < ActiveRecord::Migration
  def self.up
    remove_column :configurations, :tc_contracts_per_provider_in_wan
    remove_column :configurations, :tc_contracts_per_provider_in_lan
    remove_column :configurations, :use_global_prios
    remove_column :configurations, :use_global_prios_strategy
    remove_column :configurations, :mtu
    remove_column :configurations, :quantum_factor
  end

  def self.down
    add_column :configurations, :tc_contracts_per_provider_in_wan, :boolean, :default => false
    add_column :configurations, :tc_contracts_per_provider_in_lan, :boolean, :default => false
    add_column :configurations, :use_global_prios, :boolean, :default => false
    add_column :configurations, :use_global_prios_strategy, :string, :default => 'provider'
    add_column :configurations, :mtu, :integer, :default => 1500
    add_column :configurations, :quantum_factor, :string, :default => "256"
  end
end
