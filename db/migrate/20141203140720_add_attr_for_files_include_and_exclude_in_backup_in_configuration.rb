class AddAttrForFilesIncludeAndExcludeInBackupInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :files_include_in_backup, :text
    add_column :configurations, :files_exclude_in_backup, :text
  end

  def self.down
    remove_column :configurations, :files_include_in_backup
    remove_column :configurations, :files_exclude_in_backup
  end
end
