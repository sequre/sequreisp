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
  ACCEPTED_LOCALES = ["es","en","pt"]
  GUIDES_URL = "http://doc.sequreisp.com/index.php?title=P%C3%A1gina_principal"

  PATH_DNS_NAMED_OPTIONS = Rails.env.production? ? "/etc/bind/named.conf.options" : "/tmp/named.conf.options"

  def self.acts_as_audited_except
    [:daemon_reload]
  end

  acts_as_audited :except => self.acts_as_audited_except

  include ModelsWatcher
  watch_fields :default_tcp_prio_ports, :default_udp_prio_ports, :default_prio_protos, :default_prio_helpers,
               :mtu, :quantum_factor, :nf_conntrack_max, :gc_thresh1, :gc_thresh2, :gc_thresh3,
               :transparent_proxy, :transparent_proxy_n_to_m, :transparent_proxy_zph_enabled,
               :transparent_proxy_windows_update_hack,
               :tc_contracts_per_provider_in_lan, :tc_contracts_per_provider_in_wan,
               :filter_by_mac_address, :clamp_mss_to_pmtu, :use_global_prios, :use_global_prios_strategy,
               :iptables_tree_optimization_enabled,
               :web_interface_listen_on_80, :web_interface_listen_on_443, :web_interface_listen_on_8080

  validates_presence_of :default_tcp_prio_ports, :default_prio_protos, :default_prio_helpers, :mtu, :quantum_factor, :nf_conntrack_max, :gc_thresh1, :gc_thresh2, :gc_thresh3
  validates_presence_of :notification_email, :if => Proc.new { |c| c.deliver_notifications? }
  validates_presence_of :notification_timeframe
  validates_presence_of :language

  validates_format_of :default_tcp_prio_ports, :default_udp_prio_ports, :default_prio_protos, :default_prio_helpers, :with => /^([0-9a-z-]+,)*[0-9a-z-]+$/, :allow_blank => true

  validates_numericality_of :notification_timeframe, :only_integer => true, :greater_than_or_equal_to => 0
  validates_numericality_of :transparent_proxy_max_load_average, :only_integer => true, :greater_than => 0, :less_than => 30
  validates_numericality_of :logged_in_timeout, :only_integer => true, :greater_than_or_equal_to => 0
  validates_presence_of :apply_changes_automatically_hour, :if => :apply_changes_automatically?

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

  def use_global_prios_strategy_options_for_select
    [
      [I18n.t('selects.configuration.use_global_prios_strategy.disabled'), 'disabled'],
      [I18n.t('selects.configuration.use_global_prios_strategy.provider'), 'provider'],
      [I18n.t('selects.configuration.use_global_prios_strategy.full'), 'full']
    ]
  end

  def use_global_prios_strategy
    ActiveSupport::StringInquirer.new read_attribute(:use_global_prios_strategy)
  end

  # this can be overrided from a plug-in like invocing
  def day_of_the_beginning_of_the_period
    1
  end

  def generate_bind_dns_named_options
    hash = {}
    hash[:forwarders] = []

    if dns_use_forwarders
      hash[:forwarders] << "        #{dns_first_server};" if dns_first_server.present?
      hash[:forwarders] << "        #{dns_second_server};" if dns_second_server.present?
      hash[:forwarders] << "        #{dns_third_server};" if dns_third_server.present?
    else
      hash[:forwarders] = ["//      8.8.8.8;", "//      8.8.4.4;"]
    end

    named_options = File.open(PATH_DNS_NAMED_OPTIONS, "w")
    view = ActionView::Base.new(ActionController::Base.view_paths, {})
    named_options.puts view.render(:file => "configurations/named.conf.options.erb", :locals => {:params => hash})
    named_options.close
  end
end
