class AddDaemonsLastExecutionTimeToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :daemon_apply_change_automatically_last_execution_time, :datetime
    add_column :configurations, :daemon_synchronize_time_last_execution_time, :datetime
  end

  def self.down
    remove_column :configurations, :daemon_apply_change_automatically_last_execution_time
    remove_column :configurations, :daemon_synchronize_time_last_execution_time
  end
end
