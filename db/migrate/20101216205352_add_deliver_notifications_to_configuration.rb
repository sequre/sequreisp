class AddDeliverNotificationsToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :deliver_notifications, :boolean, :default => false
    Configuration.reset_column_information
    c = Configuration.first
    if c and !c.notification_email.blank?
      Configuration.update_all('deliver_notifications = 1')
    end
  end

  def self.down
    remove_column :configurations, :deliver_notifications
  end
end
