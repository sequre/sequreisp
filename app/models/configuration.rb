# Sequreisp - Copyright 2010, 2011 Luciano Ruete
#
# This file is part of Sequreisp.
#
# Sequreisp is free software: you can redistribute it and/or modify
# it under the terms of the GNU Afero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sequreisp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Afero General Public License for more details.
#
# You should have received a copy of the GNU Afero General Public License
# along with Sequreisp.  If not, see <http://www.gnu.org/licenses/>.

class Configuration < ActiveRecord::Base
  require 'sequreisp_constants'

  ACCEPTED_LOCALES = ["es","en","pt"]
  GUIDES_URL = "http://doc.wispro.co/index.php?title=P%C3%A1gina_principal"

  PATH_POSTFIX = Rails.env.production? ? "/etc/postfix/main.cf" : "/tmp/main.cf"
  PATH_SASL_PASSWD = Rails.env.production? ? "/etc/postfix/sasl_passwd" : "/tmp/sasl_passwd"
  PATH_DNS_NAMED_OPTIONS = Rails.env.production? ? "/etc/bind/named.conf.options" : "/tmp/named.conf.options"
  PATH_COMMAND_LOG = Rails.env.production? ? HUMANIZED_COMMAND_LOG : "/tmp/command_log"
  APPLY_CHANGES_LOCK = "#{DEPLOY_DIR}/tmp/apply_changes.lock"

  LOW_LATENCY_TRAFFIC_PRIO = [ "tcp-length", "udp-length", "ssh", "dns", "icmp", "sip", "rtp" ]

  COUNT_CATEGORIES = ["data_count"]

  def self.acts_as_audited_except
    [:daemon_reload]
  end

  acts_as_audited :except => self.acts_as_audited_except

  include IpAddressCheck
  include ModelsWatcher
  watch_fields :default_tcp_prio_ports, :default_udp_prio_ports, :default_prio_protos, :default_prio_helpers,
               :nf_conntrack_max, :gc_thresh1, :gc_thresh2, :gc_thresh3,
               :filter_by_mac_address, :clamp_mss_to_pmtu,
               :web_interface_listen_on_80, :web_interface_listen_on_443, :web_interface_listen_on_8080,
               :mail_relay_manipulated_for_sequreisp, :mail_relay_used, :mail_relay_option_server, :mail_relay_smtp_server, :mail_relay_smtp_port, :mail_relay_mail, :mail_relay_password,
               :dns_use_forwarders, :dns_first_server, :dns_second_server, :dns_third_server, :traffic_prio

  validates_presence_of :default_tcp_prio_ports, :default_prio_protos, :default_prio_helpers, :nf_conntrack_max, :gc_thresh1, :gc_thresh2, :gc_thresh3
  validates_presence_of :notification_email, :if => Proc.new { |c| c.deliver_notifications? }
  validates_presence_of :notification_timeframe
  validates_presence_of :language
  validates_presence_of :mail_relay_option_server, :mail_relay_smtp_server, :mail_relay_smtp_port, :mail_relay_mail, :mail_relay_password, :if => "mail_relay_used == true"

  validates_format_of :default_tcp_prio_ports, :default_udp_prio_ports, :default_prio_protos, :default_prio_helpers, :with => /^([0-9a-z-]+,)*[0-9a-z-]+$/, :allow_blank => true

  validates_numericality_of :notification_timeframe, :only_integer => true, :greater_than_or_equal_to => 0
  validates_numericality_of :logged_in_timeout, :only_integer => true, :greater_than_or_equal_to => 0
  validates_presence_of :apply_changes_automatically_hour, :if => :apply_changes_automatically?

  validate :presence_of_dns_server
  validate_ip_format_of :dns_first_server, :dns_second_server, :dns_third_server
  validate :not_repeat_traffic_prio

  def not_repeat_traffic_prio
    prios = []
    traffic_prio.split(",").each do |prio|
      prios << prio if (default_tcp_prio_ports + default_udp_prio_ports + default_prio_protos + default_prio_helpers).include?(prio)
    end
    errors.add_to_base(I18n.t("error_messages.cant_repeat_the_ports", :ports => prios.join(','))) unless prios.empty?
  end

  def presence_of_dns_server
    if dns_use_forwarders and not (dns_first_server.present? or dns_second_server.present? or dns_third_server.present?)
      errors.add_to_base(I18n.t('error_messages.define_one_dns_server'))
    end
  end

  include PriosCheck
  def validate
    validate_in_range_or_in_file(:default_tcp_prio_ports, 0,65536, :service)
    validate_in_range_or_in_file(:default_udp_prio_ports, 0,65536, :service)
    validate_in_range_or_in_file(:default_prio_protos, -1,256, :protocol)
    validate_in_range_or_in_file(:default_prio_helpers, 0, 0, :helper)

    if !notification_email.blank?
      invalid=false
      notification_email.split(",").each do |ne|
        invalid ||= ((ne =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i) == nil)
      end
      errors.add("notification_email", I18n.t('validations.configuration.notification_email_invalid')) if invalid
    end
    unless web_interface_listen_on_80 or web_interface_listen_on_443 or web_interface_listen_on_8080
      errors.add("web_interface_listen_on_8080", I18n.t("validations.configuration.web_interface_listen_at_least_on_one_port"))
    end
  end

  private_class_method :new, :create, :destroy, :destroy_all, :delete, :delete_all

  @@c = find(:first) rescue nil

  def self.do_reload
    @@c = find(:first)
  end

  def low_latency_traffic_prio_rules
    { "tcp-length" => ["-p tcp -m length --length 0:#{tcp_length}"],
      "udp-length" => ["-p udp -m length --length 0:#{udp_length}"],
      "ssh" => ["-p tcp --dport 22", "-p tcp --sport 22"],
      "dns" => ["-p tcp --dport 53", "-p tcp --sport 53"],
      "icmp" => ["-p icmp"],
      "sip" => ["-m helper --helper sip"],
      "rtp" => ["-p udp --dport 10000:20000"] }
  end

  def self.parse_traffic_prio(params)
    params.has_key?(:traffic_prio) ? params[:traffic_prio].keys.select{|prio| prio != ""}.join(",") : ""
  end

  def self.method_missing(method, *args)
    opcion = method.to_s
    if opcion.include? '='
      # Asignar un valor a la opción
      valor = args.first
      @@c.send opcion, valor
    elsif @@c.respond_to? opcion
      # Retornar el valor de la opción
      @@c.send opcion
    else
      super method, args
    end
  end

  def self.save
    @@c.save
  end

  def self.update_attributes(atributos)
    @@c.update_attributes(atributos)
  end

  def self.errors
    @@c.errors
  end
  def apply_changes
    self.last_changes_applied_at = Time.now
    self.changes_to_apply = false
    self.daemon_reload = true
    save
  end

  def auditable_name
    self.class.human_name
  end

  include CommaSeparatedArray
  comma_separated_array_field :default_prio_protos, :default_prio_helpers, :default_tcp_prio_ports, :default_udp_prio_ports

  def self.apply_changes_automatically!
    return if Time.now.hour != apply_changes_automatically_hour
    apply_changes if changes_to_apply?
  end

  # this can be overrided from a plug-in like invocing
  def day_of_the_beginning_of_the_period
    1
  end

  def generate_postfix_main
    generate_postmap = false
    hash= {}
    hash["relayhost"] = ""
    hash["myhostname"] = `cat /etc/mailname`.strip
    if mail_relay_used?
      generate_postmap = true
      hash["smtp_sasl_password_maps"] = "hash:#{PATH_SASL_PASSWD}"
      hash["smtp_sasl_auth_enable"] = "yes"
      case mail_relay_option_server
      when "own"
        hash["relayhost"] = "#{self.mail_relay_smtp_server}:#{self.mail_relay_smtp_port}"
        hash["smtp_sasl_security_options"] = ""

        sasl_passwd = File.open(PATH_SASL_PASSWD, "w")
        sasl_passwd.puts("#{self.mail_relay_smtp_server}:#{self.mail_relay_smtp_port} #{self.mail_relay_mail}:#{self.mail_relay_password}")
        sasl_passwd.close
      when "gmail"
        hash["relayhost"] = "[#{self.mail_relay_smtp_server}]:#{self.mail_relay_smtp_port}"
        hash["smtp_use_tls"] = "yes"
        hash["smtp_sasl_security_options"] = ""
        hash["smtp_tls_CAfile"] = "/etc/ssl/certs/ca-certificates.crt"

        sasl_passwd = File.open(PATH_SASL_PASSWD, "w")
        sasl_passwd.puts("[#{self.mail_relay_smtp_server}]:#{self.mail_relay_smtp_port} #{self.mail_relay_mail}:#{self.mail_relay_password}")
        sasl_passwd.close
        # when "yahoo"
      end
    end
    write_main_postfix(hash)
    generate_postmap
  end

  def write_main_postfix(options)
    postfix_main = File.open(PATH_POSTFIX, "w")
    view = ActionView::Base.new(ActionController::Base.view_paths, {})
    postfix_main.puts view.render(:file => "configurations/postfix.conf.erb", :locals => {:params => options})
    postfix_main.close
  end
  def generate_bind_dns_named_options
    hash = {}
    hash[:forwarders] = []

    if dns_use_forwarders
      hash[:forwarders] << "forwarders {"
      hash[:forwarders] << "      #{dns_first_server};" if dns_first_server.present?
      hash[:forwarders] << "      #{dns_second_server};" if dns_second_server.present?
      hash[:forwarders] << "      #{dns_third_server};" if dns_third_server.present?
      hash[:forwarders] << "};"
    else
      hash[:forwarders] << "// forwarders {"
      hash[:forwarders] << "//      8.8.8.8;"
      hash[:forwarders] << "//      8.8.4.4;"
      hash[:forwarders] << "// };"
    end

    named_options = File.open(PATH_DNS_NAMED_OPTIONS, "w")
    view = ActionView::Base.new(ActionController::Base.view_paths, {})
    named_options.puts view.render(:file => "configurations/named.conf.options.erb", :locals => {:params => hash})
    named_options.close
  end

  def self.app_listen_port_available
    ports = []
    if web_interface_listen_on_80
      ports << "80"
    end
    if web_interface_listen_on_8080
      ports << "8080"
    end
    if web_interface_listen_on_443
      ports << "443"
    end
    ports
  end

  def self.is_apply_changes?
    File.exists?(APPLY_CHANGES_LOCK)
  end

  def include_exclude_files_in_backup(backup)
    self.files_include_in_backup = backup[:include_files].delete("\r")
    self.files_exclude_in_backup = backup[:exclude_files].delete("\r")
    self.save
  end

  def self.app_version
    require 'sequreisp_about'
    SequreISP::Version.to_s
  end

  # This method is rewrite
  def self.daemons
    (Dir.entries("#{DEPLOY_DIR}/tmp") -[".", ".."]).select{|file| file.include?("daemon_")}.sort
  end
##############################################################
#
##############################################################
end
