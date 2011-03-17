class AddNotificationEmailToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :notification_email, :string
  end

  def self.down
    remove_column :configurations, :notification_email
  end
end
