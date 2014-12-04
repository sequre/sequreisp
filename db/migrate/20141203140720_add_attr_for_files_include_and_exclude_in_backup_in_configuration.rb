class AddAttrForFilesIncludeAndExcludeInBackupInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :files_include_in_buckup, :text
    add_column :configurations, :files_exclude_in_buckup, :text
  end

  def self.down
    remove_column :configurations, :files_include_in_buckup
    remove_column :configurations, :files_exclude_in_buckup
  end
end
