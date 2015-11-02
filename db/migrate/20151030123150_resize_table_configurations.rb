class ResizeTableConfigurations < ActiveRecord::Migration
  def self.up
    change_column :configurations, :default_tcp_prio_ports, :text
    change_column :configurations, :default_udp_prio_ports, :text
    change_column :configurations, :default_prio_protos, :text
    change_column :configurations, :default_prio_helpers, :text
    change_column :configurations, :notification_email, :text
    change_column :configurations, :time_zone, :string, :limit => 40
    change_column :configurations, :logo_file_name, :text
    change_column :configurations, :logo_content_type, :string, :limit => 35
    change_column :configurations, :contact_email, :text
    change_column :configurations, :contact_phone, :text
    change_column :configurations, :contact_address, :text
    change_column :configurations, :company_name, :text
    change_column :configurations, :language, :string, :limit => 5
    change_column :configurations, :backup_restore, :string, :limit => 20
    change_column :configurations, :apply_changes_automatically_hour, :integer, :limit => 1
    change_column :configurations, :tcp_length, :integer, :limit => 2
    change_column :configurations, :udp_length, :integer, :limit => 2
    change_column :configurations, :firewall_open_tcp_ports, :text
    change_column :configurations, :firewall_open_udp_ports, :text
    change_column :configurations, :mail_relay_option_server, :string, :limit => 10
    change_column :configurations, :mail_relay_smtp_server, :text
    change_column :configurations, :mail_relay_smtp_port, :integer, :limit => 2
    change_column :configurations, :mail_relay_mail, :text
    change_column :configurations, :mail_relay_password, :text
    change_column :configurations, :dns_first_server, :string, :limit => 20
    change_column :configurations, :dns_second_server, :string, :limit => 20
    change_column :configurations, :dns_third_server, :string, :limit => 20
  end

  def self.down
    change_column :configurations, :default_tcp_prio_ports, :string
    change_column :configurations, :default_udp_prio_ports, :string
    change_column :configurations, :default_prio_protos, :string
    change_column :configurations, :default_prio_helpers, :string
    change_column :configurations, :notification_email, :string
    change_column :configurations, :time_zone, :string
    change_column :configurations, :logo_file_name, :string
    change_column :configurations, :logo_content_type, :string
    change_column :configurations, :contact_email, :string
    change_column :configurations, :contact_phone, :text
    change_column :configurations, :contact_address, :text
    change_column :configurations, :company_name, :text
    change_column :configurations, :language, :string
    change_column :configurations, :backup_restore, :string
    change_column :configurations, :apply_changes_automatically_hour, :integer
    change_column :configurations, :tcp_length, :integer
    change_column :configurations, :udp_length, :integer
    change_column :configurations, :firewall_open_tcp_ports, :string
    change_column :configurations, :firewall_open_udp_ports, :string
    change_column :configurations, :mail_relay_option_server, :string
    change_column :configurations, :mail_relay_smtp_server, :string
    change_column :configurations, :mail_relay_smtp_port, :integer
    change_column :configurations, :mail_relay_mail, :string
    change_column :configurations, :mail_relay_password, :string
    change_column :configurations, :dns_first_server, :string
    change_column :configurations, :dns_second_server, :string
    change_column :configurations, :dns_third_server, :string
  end
end
