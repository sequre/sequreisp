class AddAttrForMailRelayInConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :mail_relay_manipulated_for_sequreisp, :boolean, :default => false
    add_column :configurations, :mail_relay_used, :boolean, :default => false
    add_column :configurations, :mail_relay_option_server, :string
    add_column :configurations, :mail_relay_smtp_server, :string
    add_column :configurations, :mail_relay_smtp_port, :integer
    add_column :configurations, :mail_relay_mail, :string
    add_column :configurations, :mail_relay_password, :string
  end

  def self.down
    remove_column :configurations, :mail_relay_manipulated_for_sequreisp
    remove_column :configurations, :mail_relay_used
    remove_column :configurations, :mail_relay_option_server
    remove_column :configurations, :mail_relay_smtp_server
    remove_column :configurations, :mail_relay_smtp_port
    remove_column :configurations, :mail_relay_mail
    remove_column :configurations, :mail_relay_password
  end
end
