class AddLastChangesAppliedAtToConfigurations < ActiveRecord::Migration
  def self.up
    add_column :configurations, :last_changes_applied_at, :timestamp
  end

  def self.down
    remove_column :configurations, :last_changes_applied_at
  end
end
