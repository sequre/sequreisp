class AddChangesToApplyToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :changes_to_apply, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :changes_to_apply
  end
end
