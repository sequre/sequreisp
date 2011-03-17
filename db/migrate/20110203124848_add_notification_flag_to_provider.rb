class AddNotificationFlagToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :notification_flag, :boolean, :default => false
  end

  def self.down
    remove_column :providers, :notification_flag
  end
end
