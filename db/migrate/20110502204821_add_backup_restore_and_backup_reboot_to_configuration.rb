class AddBackupRestoreAndBackupRebootToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :backup_reboot, :boolean, :default => false
    add_column :configurations, :backup_restore, :string, :default => nil
  end

  def self.down
    remove_column :configurations, :backup_restore
    remove_column :configurations, :backup_reboot
  end
end
