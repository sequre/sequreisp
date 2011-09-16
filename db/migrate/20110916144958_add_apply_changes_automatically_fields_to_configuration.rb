class AddApplyChangesAutomaticallyFieldsToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :apply_changes_automatically, :boolean, :default => false
    add_column :configurations, :apply_changes_automatically_hour, :integer, :default => 4
  end

  def self.down
    remove_column :configurations, :apply_changes_automatically_hour
    remove_column :configurations, :apply_changes_automatically
  end
end
