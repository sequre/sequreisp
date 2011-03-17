class AddConsumptionsToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :consumption_down_prio, 'bigint unsigned', :default => 0
    add_column :providers, :consumption_up_prio, 'bigint unsigned', :default => 0
    add_column :providers, :consumption_down_dfl, 'bigint unsigned', :default => 0
    add_column :providers, :consumption_up_dfl, 'bigint unsigned', :default => 0
  end

  def self.down
    remove_column :providers, :consumption_up_dfl
    remove_column :providers, :consumption_down_dfl
    remove_column :providers, :consumption_up_prio
    remove_column :providers, :consumption_down_prio
  end
end
