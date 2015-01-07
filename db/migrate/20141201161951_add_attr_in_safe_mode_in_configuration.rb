class AddAttrInSafeModeInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :in_safe_mode, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :in_safe_mode
  end
end
