class RenameDaemonsLastExecutionTimeInConfiguration < ActiveRecord::Migration
  def self.up
    rename_column :configurations, :daemon_apply_change_automatically_last_execution_time, :daemon_apply_change_automatically_next_exec_time
    rename_column :configurations, :daemon_synchronize_time_last_execution_time, :daemon_synchronize_time_next_exec_time
  end

  def self.down
    rename_column :configurations, :daemon_apply_change_automatically_next_exec_time, :daemon_apply_change_automatically_last_execution_time
    rename_column :configurations, :daemon_synchronize_time_next_exec_time, :daemon_synchronize_time_last_execution_time
  end
end
