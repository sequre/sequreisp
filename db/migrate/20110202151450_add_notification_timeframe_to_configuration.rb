class AddNotificationTimeframeToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :notification_timeframe, :integer, :default => 60
  end

  def self.down
    remove_column :configurations, :notification_timeframe
  end
end
