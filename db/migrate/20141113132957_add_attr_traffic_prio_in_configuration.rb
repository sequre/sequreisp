class AddAttrTrafficPrioInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :traffic_prio, :string, :default => ""
  end

  def self.down
    remove_column :configurations, :traffic_prio
  end
end
