class AddNoIfbOnLanToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :no_ifb_on_lan, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :no_ifb_on_lan
  end
end
