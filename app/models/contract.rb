
# -*- coding: utf-8 -*-
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

class Contract < ActiveRecord::Base
  require 'sequreisp_logger'
  acts_as_audited :except => [:netmask,
                              :queue_down_prio, :queue_up_prio, :queue_down_dfl, :queue_up_dfl,
                              :consumption_down_prio, :consumption_up_prio, :consumption_down_dfl, :consumption_up_dfl, :is_connected]
  def initialize(attributes = nil)
    super(attributes)
    self.start_date = Date.today if start_date.nil?
  end

  belongs_to :client
  belongs_to :plan

  has_many :forwarded_ports, :dependent => :destroy
  accepts_nested_attributes_for :forwarded_ports, :reject_if => :all_blank, :allow_destroy => true
  has_one :klass, :dependent => :nullify
  has_one :provider_group, :through => :plan
  belongs_to :public_address, :class_name => 'Address', :conditions => "addressable_id is not null and addressable_type = 'provider'"
  belongs_to :proxy_arp_interface, :class_name => 'Interface', :conditions => "kind = 'lan'"
  belongs_to :proxy_arp_provider, :class_name => 'Provider'
  belongs_to :unique_provider, :class_name => 'Provider'
  has_many :traffics, :dependent => :destroy
  has_one :current_traffic, :class_name => 'Traffic', :conditions => ["traffics.from_date <= ? and traffics.to_date >= ?", Date.today, Date.today]

  named_scope :enabled, :conditions => { :state => "enabled" }
  named_scope :not_disabled, :conditions => "state != 'disabled'"

  #este se usa para generar las reglas, ordena por netmask para asegurarse que las redes más grandes queden al final
  named_scope :descend_by_netmask, :order => "CAST(INET_ATON(netmask) AS UNSIGNED) DESC, CAST(INET_ATON(SUBSTRING_INDEX(ip, '/', 1)) AS UNSIGNED) ASC"

  named_scope :ascend_by_ip_custom, :order => "CAST(INET_ATON(SUBSTRING_INDEX(contracts.ip, '/', 1)) AS UNSIGNED) ASC, CAST(INET_ATON(contracts.netmask) AS UNSIGNED) ASC"
  named_scope :descend_by_ip_custom, :order => "CAST(INET_ATON(SUBSTRING_INDEX(contracts.ip, '/', 1)) AS UNSIGNED) DESC, CAST(INET_ATON(contracts.netmask) AS UNSIGNED) DESC"
  named_scope :how_many_connected, :conditions => {:is_connected => true}

  include ModelsWatcher
  watch_fields :ip, :plan_id, :mac_address, :ceil_dfl_percent, :state,
               :tcp_prio_ports, :udp_prio_ports, :prio_protos, :prio_helpers,
               :proxy_arp, :proxy_arp_interface_id, :public_address_id,
               :unique_provider_id,
               :proxy_arp_provider_id, :proxy_arp_gateway, :proxy_arp_use_lan_gateway, :proxy_arp_lan_gateway
  watch_on_destroy

  before_validation :strip_whitespace, :only => [:tcp_prio_ports, :udp_prio_ports, :prio_protos, :prio_helpers]

  validates_presence_of :ip, :ceil_dfl_percent, :client, :plan
  validates_presence_of :proxy_arp_interface, :if => Proc.new { |c| c.proxy_arp }
  validates_presence_of :proxy_arp_lan_gateway, :if => Proc.new { |c| c.proxy_arp_use_lan_gateway }

  validates_format_of :tcp_prio_ports, :udp_prio_ports, :prio_protos, :prio_helpers, :with => /^([0-9a-z-]+(:[0-9]+)*,)*[0-9a-z-]+(:[0-9]+)*$/, :allow_blank => true
  validates_format_of :mac_address, :with => /^([0-9A-Fa-f]{2}\:){5}[0-9A-Fa-f]{2}$/, :allow_blank => true

  validates_numericality_of :ceil_dfl_percent, :only_integer => true, :greater_than => 0, :less_than_or_equal_to => 100

  validates_uniqueness_of :ip, :allow_nil => true, :allow_blank => true
  validates_uniqueness_of :mac_address, :allow_nil => true, :allow_blank => true

  validate :state_should_be_included_in_the_list
  validate :uniqueness_mac_address_in_interfaces_lan

  def uniqueness_mac_address_in_interfaces_lan
    if (interface = Interface.only_lan.all(:conditions => { :mac_address => self.mac_address })).count > 0
      errors.add(:mac_address, I18n.t('validations.contract.mac_address_taken_in_interface', :interface_id => interface.first.id ) )
     end
  end

  def state_should_be_included_in_the_list
    unless AASM::StateMachine[Contract].states.map(&:name).include?(state.to_sym)
      errors.add(:state, I18n.t('activerecord.errors.messages.inclusion'))
    end
  end

  validate :check_invalid_options, :if => Proc.new {|c| not c.netmask.nil? and not c.ip_is_single_host? }
    #:unless => :ip_is_single_host?
  def check_invalid_options

    if self.proxy_arp
      errors.add :proxy_arp, I18n.t("validations.contract.proxy_arp_incompatible_if_ip_is_a_network")
    end

    if self.public_address
      errors.add :public_address, I18n.t("validations.contract.full_dnat_incompatible_if_ip_is_a_network")
    end

    #cant_forward_port_if_contract_ip_is_single_host
    if forwarded_ports.any?
      errors.add :ip, I18n.t("validations.forwarded_port.cant_forward_port_if_contract_ip_is_single_host")
      for fw in forwarded_ports do
        fw.errors.add_to_base I18n.t("validations.forwarded_port.cant_forward_port_if_contract_ip_is_single_host")
      end
    end
  end
  include IpAddressCheck
  validate_ip_format_of :ip, :with_netmask => true
  validate_ip_format_of :proxy_arp_gateway, :with_netmask => false
  validate_ip_format_of :proxy_arp_lan_gateway, :with_netmask => false

  def ip_is_single_host?
    netmask == "255.255.255.255"
  end

  include PriosCheck
  def validate
    if not ip.blank?
      # Address tiene las ips de las interfaces y los  proveedores
      if Address.find_by_ip(ip) or Provider.find_by_ip(ip)
        errors.add(:ip, I18n.t('validations.ip_already_in_use'))
      end
    end
    validate_in_range_or_in_file(:tcp_prio_ports, 0,65536, :service)
    validate_in_range_or_in_file(:udp_prio_ports, 0,65536, :service)
    validate_in_range_or_in_file(:prio_protos, -1,256, :protocol)
    validate_in_range_or_in_file(:prio_helpers, 0, 0, :helper)

    if not public_address_id.nil?
      in_use = nil
      if self.id.nil?
        in_use = Contract.first(:conditions => { :public_address_id => public_address_id })
      else
        in_use = Contract.first(:conditions => ["public_address_id = ? and id != ?", public_address_id, self.id])
      end
      errors.add(:public_address, I18n.t('validations.contract.public_address_already_in_use', :client_name => in_use.client.name)) if in_use
      if not self.plan_id.nil? and Plan.find(plan_id).provider_group_id != public_address.addressable.provider_group_id
        errors.add(:public_address, I18n.t('validations.contract.public_address_does_not_belongs_to_plan'))
      end
      if proxy_arp
        errors.add(:proxy_arp, I18n.t('validations.contract.proxy_arp_incompatible_with_full_dnat'))
      end
    end
    if not unique_provider_id.nil? and not plan_id.nil?
      _provider = Provider.find unique_provider_id
      _plan = Plan.find plan_id
      if _provider.provider_group_id != _plan.provider_group_id
        errors.add(:unique_provider, I18n.t('validations.contract.unique_provider_does_not_belongs_to_plan'))
      end
    end
    # Often occurs that we have a second pool of ip address that is not configured in the provider itself
    # Also is possible that we can not use a wider mask than /32, and still have the pool
    if proxy_arp
      if guess_proxy_arp_provider.nil? and proxy_arp_provider_id.nil?
        errors.add(:proxy_arp_provider, I18n.t('validations.contract.proxy_arp_provider_can_not_be_guessed'))
      end
      if plan_id
        _proxy_arp_provider = Provider.find proxy_arp_provider_id rescue nil
        _proxy_arp_provider = guess_proxy_arp_provider if _proxy_arp_provider.nil?
        _providers_ids = Plan.find(plan_id).provider_ids

        if _proxy_arp_provider and not _providers_ids.include?(_proxy_arp_provider.id)
          errors.add(:proxy_arp_provider, I18n.t('validations.contract.proxy_arp_provider_does_not_belongs_to_plan'))
        end
      end
    end
  end

  include OverflowCheck
  before_save :check_integer_overflow
  before_create :bind_klass
  before_update :clean_proxy_arp_provider_proxy_arp_interface, :if => "proxy_arp_changed? and proxy_arp == false"
  after_save :create_traffic_for_this_period

  def create_traffic_for_this_period
    if self.current_traffic.nil?
      from_date = Date.new(Date.today.year, Date.today.month, Configuration.first.day_of_the_beginning_of_the_period)
      attr = {}
      if Date.today.day < Configuration.first.day_of_the_beginning_of_the_period
        attr[:from_date] = from_date - 1.month
        attr[:to_date] = from_date - 1.day
      else
        attr[:from_date] = from_date
        attr[:to_date] = from_date + 1.month - 1.day
      end
      traffics.create(attr)
    end
  end

  def clean_proxy_arp_provider_proxy_arp_interface
    self.proxy_arp_interface_id = nil
    self.proxy_arp_provider_id = nil
    self.proxy_arp_gateway = ""
    self.proxy_arp_use_lan_gateway = false
    self.proxy_arp_lan_gateway = ""
  end

  alias :real_klass :klass
  def klass
    bind_klass if real_klass.nil?
    real_klass
  end

  def ip= val
    write_attribute(:ip, val)
    save_netmask
  end

  def save_netmask
    self.netmask = IP.new(self.ip).netmask.to_s rescue nil
  end
  def bind_klass
    self.klass = Klass.find(:first, :conditions => "contract_id is null", :lock => "for  update")
    raise "TODO nos quedamos sin clases!" if self.klass.nil?
  end

  after_update :queue_update_commands
  after_destroy :queue_destroy_commands

  def queue_update_commands
    cq = QueuedCommand.new
    _interface = Interface.find(proxy_arp_interface_id_was) rescue nil
    if _interface
      begin
        p_was = proxy_arp_provider_id_was.present? ? Provider.find(proxy_arp_provider_id_was) : guess_proxy_arp_provider(ip_was) rescue nil
        g_ip_was = proxy_arp_gateway_was.present? ? proxy_arp_gateway_was : p_was.gateway rescue nil
        if proxy_arp_changed?
          if proxy_arp_was
            # User de-activate proxy_arp
            if p_was
              cq.command += "arp -i #{p_was.interface.name} -d #{ip_was};"
              cq.command += "arp -i #{_interface.name} -d #{g_ip_was};"
            end
            if proxy_arp_use_lan_gateway_was
              cq.command += "ip ro del #{ip_was} via #{proxy_arp_lan_gateway_was} dev #{_interface.name};"
            else
              cq.command += "ip ro del #{ip_was} dev #{_interface.name};"
            end
          end
        elsif proxy_arp
          # proxy_arp does not changed but is active, so check if other options changed
          if proxy_arp_interface_id_changed? or ip_changed? or proxy_arp_use_lan_gateway_changed? or proxy_arp_lan_gateway_changed? or proxy_arp_provider_id_changed?
            cq.command += "arp -i #{_interface.name} -d #{g_ip_was};" if p_was and ( proxy_arp_interface_id_changed? or proxy_arp_provider_id_changed? )
            cq.command += "arp -i #{p_was.interface.name} -d #{ip_was};" if p_was and ( ip_changed? or proxy_arp_provider_id_changed? )

            if proxy_arp_use_lan_gateway_was
              cq.command += "ip ro del #{ip_was} via #{proxy_arp_lan_gateway_was} dev #{_interface.name};"
            else
              cq.command += "ip ro del #{ip_was} dev #{_interface.name};"
            end
          end
          #if proxy_arp_lan_gateway_changed? and proxy_arp_lan_gateway_was
          #  cq.command += "ip ro del #{ip_was} via #{proxy_arp_lan_gateway_was} dev #{_interface.name};"
          #end
        end
      rescue => e
        log_rescue("[Model][Contract][Queue_update_commands]", e)
        Rails.logger.error "ERROR: Contract::queue_update_commands #{e.inspect}"
      end
    end
    cq.save if not cq.command.empty?
  end

  def queue_destroy_commands
    cq = QueuedCommand.new
    if proxy_arp
      cq.command += "arp -i #{proxy_arp_interface.name} -d #{ip};"
      if proxy_arp_use_lan_gateway
        cq.command += "ip ro del #{ip} via #{proxy_arp_lan_gateway} dev #{proxy_arp_interface.name};"
      else
        cq.command += "ip ro del #{ip} dev #{proxy_arp_interface.name};"
      end
    end
    cq.save if not cq.command.empty?
  end

  #AASM conf http://github.com/rubyist/aasm
  include AASM
  aasm_column :state
  aasm_initial_state :enabled
  aasm_state :enabled rescue nil
  aasm_state :disabled rescue nil

  def state
    s = self[:state]
    if not s.respond_to?(:human)
      def s.human
        I18n.t "aasm.contract.#{self}"
      end
    end
    s
  end

  aasm_event :enable do
    transitions :from => :disabled, :to => :enabled
  end

  aasm_event :disable do
    transitions :from => :enabled, :to => :disabled
  end

  def self.aasm_states_for_select
    AASM::StateMachine[self].states.map { |state| [I18n.t("aasm.contract.#{state.name.to_s}"),state.name.to_s] }
  end

  def aasm_states_for_select
    Contract.aasm_states_for_select
  end

  def name
    plan.name
  end

  def guess_proxy_arp_provider(alt_ip=nil)
    begin
      c_ip = alt_ip.nil? ? IP.new(self.ip) : IP.new(alt_ip)
      provider=nil
      Plan.find(plan_id).providers.ready.each do |p|
        p_ip = IP.new "#{p.ip}/#{p.netmask_suffix}"
        provider = p if (p_ip.to_i & p_ip.netmask.to_i) == (c_ip.to_i & p_ip.netmask.to_i)
        p.addresses.each do |a|
          provider = p if (a.ruby_ip.to_i & a.ruby_ip.netmask.to_i) == (c_ip.to_i & p_ip.netmask.to_i)
        end
      end
      provider
    rescue
      provider ||= nil
      provider
    end
  end
  def class_hex
    self.klass.number.to_s(16)
  end
  def class_prio1_hex
    self.klass.prio1.to_s(16)
  end
  def class_prio2_hex
    self.klass.prio2.to_s(16)
  end
  def class_prio3_hex
    self.klass.prio3.to_s(16)
  end
  def mark_hex(prefix=0)
    (self.klass.number | prefix).to_s(16)
  end
  def mark_prio1_hex(prefix=0)
    (self.klass.prio1 | prefix).to_s(16)
  end
  def mark_prio2_hex(prefix=0)
    (self.klass.prio2 | prefix).to_s(16)
  end
  def mark_prio3_hex(prefix=0)
    (self.klass.prio3 | prefix).to_s(16)
  end
  def proxy_bind_ip
    # 198.18.0.0/15 reserved for Network Interconnect Device Benchmark Testing [RFC5735]
    # calculo una sola vez su valor en int para ahorro de computo
    IP::V4.new(IP.new("198.18.0.0") | self.klass.number).to_s
  end

  def instant
    latencies = instant_latency
    {
      :ping_latency => latencies[:ping],
      :arping_latency => latencies[:arping]
    }.merge instant_rate
  end

  # Retorna el tiempo de respuesta del cliente ante un mensaje arp o icmp
  def instant_latency
    return { :ping => rand(890)+10, :arping => rand(100)+50 } if SequreispConfig::CONFIG["demo"]
    time = {:ping => nil, :arping => nil}
    if _ip = get_address? # si es ip/32
      thread_ping = Thread.new do
        IO.popen("/bin/ping -c 1 -n -W 4 #{_ip}", "r") do |io|
          io.each do |line|
            if line.include?("time=")
              time[:ping] = line.split("time=")[1].split(" ")[0].to_f
            end
          end
        end
      end
      if iface = arping_interface
        IO.popen("sudo arping -c 1 -I #{iface} #{_ip}", "r") do |io|
          io.each do |line|
            if line.include?("ms")
              time[:arping] = line.split(" ").last.chomp.delete("ms").to_f
            end
          end
        end
      end
      thread_ping.join
    end
    time
  end

  # Obtengo su ip en caso de ser una subnet devuelve nil
  def get_address?
    _ip = IP.new(ip)
    if _ip.mask == 0
      return _ip.to_addr
    else
      return nil
    end
  end

# En caso de la red estar routeada devolvera nil (dado que debera usarse si o si
# ping) caso contrario se usara arping por lo que es necesario la interfaz
  def arping_interface
    _interface = nil
    IO.popen("ip ro get #{ip}", "r") do |io|
      io.each do |line|
        if line.include?("via")
          _interface = nil
        elsif line.include?("dev")
          _interface = line.split("dev")[1].split(" ")[0] rescue nil
        end
      end
    end
    _interface
  end

  def sent_bits(prefix)
    iface = SequreispConfig::CONFIG["ifb_#{prefix}"]
    match = false
    rate = {}
    count = 0
    klass = ""
    IO.popen("/sbin/tc -s class show dev #{iface}", "r") do |io|
      io.each do |line|
        if match and (line =~ /rate (\d+)(\w+) /) != nil
         Rails.logger.debug "Contract::instant_rate #{line}"
         _rate = $~[1].to_i
         unit = $~[2]
         # from tc manpage (s/unit)
         # kbps   Kilobytes per second
         # mbps   Megabytes per second
         # kbit   Kilobits per second
         # mbit   Megabits per second
         # bps or a bare number
         #        Bytes per second
         rate[klass] = case unit.downcase
         when "kbps"
           _rate *= 1024*8
         when "mbps"
           _rate *= 1024*1024*8
         when "kbit"
           _rate *= 1024
         when "mbit"
           _rate *= 1024*1024
         when "bit"
           _rate
         else # "bps" or a bare number
           #TODO nunca va a caer aca x "bare number" con w+ como condición de la regexp
           _rate *= 8
         end
         match = false
         count += 1
         break if count == 3
        elsif (line =~ /class hfsc 1:#{class_prio1_hex} parent 1:#{class_hex} /) != nil
           Rails.logger.debug "Contract::instant_rate #{line}"
           match = true
           klass = class_prio1_hex
        elsif (line =~ /class hfsc 1:#{class_prio2_hex} parent 1:#{class_hex} /) != nil
           Rails.logger.debug "Contract::instant_rate #{line}"
           match = true
           klass = class_prio2_hex
        elsif (line =~ /class hfsc 1:#{class_prio3_hex} parent 1:#{class_hex} /) != nil
           Rails.logger.debug "Contract::instant_rate #{line}"
           match = true
           klass = class_prio3_hex
        end
      end
    end
    rate
  end
  def instant_rate
    rate = {}
    if SequreispConfig::CONFIG["demo"]
      rate_down = rand(plan.ceil_down)*1024
      rate[:rate_down_prio1] = rate_down * 0.15
      rate[:rate_down_prio2] = rate_down * 0.6
      rate[:rate_down_prio3] = rate_down * 0.25
      rate_up = rand(plan.ceil_up)*1024 * 0.3
      rate[:rate_up_prio1] = rate_up * 0.15
      rate[:rate_up_prio2] = rate_up * 0.6
      rate[:rate_up_prio3] = rate_up * 0.25
    else
      sent = sent_bits "down"
      rate[:rate_down_prio1] = sent[class_prio1_hex]
      rate[:rate_down_prio2] = sent[class_prio2_hex]
      rate[:rate_down_prio3] = sent[class_prio3_hex]
      sent = sent_bits "up"
      rate[:rate_up_prio1] = sent[class_prio1_hex]
      rate[:rate_up_prio2] = sent[class_prio2_hex]
      rate[:rate_up_prio3] = sent[class_prio3_hex]
    end
    rate
  end

  def self.free_ips(term)
    used = free = []
    octets = term.split(".")
    prefix = octets[0..2].join "."

    used += Address.all(:conditions => ["ip like ?", "#{prefix}%"], :select => :ip).collect(&:ip)
    used += Provider.all(:conditions => ["ip like ?", "#{prefix}%"], :select => :ip).collect(&:ip)
    used += all(:conditions => ["ip like ?", "#{prefix}%"], :select => :ip).collect(&:ip)

    (1..254).each do |n|
      free << "#{prefix}.#{n.to_s}"
    end
    total = free - used
    total = total.select do |ip|
      this = ip.split(".")[3]
      this =~ /^#{octets[3]}/
    end if octets[3]
    total
  end

  include CommaSeparatedArray
  comma_separated_array_field :prio_protos, :prio_helpers, :tcp_prio_ports, :udp_prio_ports

  def netmask_suffix
    begin
      mask = IP.new(self.netmask).to_i
      count = 0
      while mask > 0 do
        mask-=(2**(31-count))
        count+=1;
      end
      count
    rescue
      nil
    end
  end

  # def mangle_chain(prefix)
  #   if Configuration.iptables_tree_optimization_enabled?
  #     suffix = netmask_suffix
  #     value = 28
  #     value -= 4 while suffix < value and value > 16
  #     _ip = IP.new("#{ip.gsub(/\/.*/, "")}/#{value}").network.to_s
  #     "sq.#{prefix}.#{_ip}"
  #   else
  #     "sequreisp.#{prefix}"
  #   end
  # end

  def auditable_name
    "#{self.class.human_name}: #{client.name} (#{ip})"
  end

  def self.slash_16_networks
    Contract.all(:select => :ip).collect { |c| c.ip.split(".")[0,2].join(".") + ".0.0/16" }.uniq
  end

  def arping_mac_address
    mac = nil
    Interface.all(:conditions => {:kind => "lan"}).each do |i|
      mac = `sudo arping #{ip} -I#{i.name} -f -w1 2>/dev/null`.split("\n").grep(/reply/).to_s.match(/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/)[0] rescue nil
      break if mac
    end
    mac
  end
  def self.to_csv(_contracts)
    # header row
    csv_string = FasterCSV.generate(:col_sep => ";") do |csv|
      csv << [
        I18n.t('activerecord.models.contract.one') + " " + I18n.t('activerecord.attributes.contract.id'),
        I18n.t('activerecord.attributes.contract.created_at'),
        I18n.t('activerecord.attributes.contract.client'),
        I18n.t('activerecord.models.client.one') + " " + I18n.t('activerecord.attributes.client.id'),
        I18n.t('activerecord.attributes.client.external_client_number'),
        I18n.t('activerecord.attributes.client.national_identification_number'),
        I18n.t('activerecord.attributes.client.email'),
        I18n.t('activerecord.attributes.client.address'),
        I18n.t('activerecord.attributes.client.phone'),
        I18n.t('activerecord.attributes.client.phone_mobile'),
        I18n.t('activerecord.attributes.client.details'),
        I18n.t('activerecord.attributes.contract.plan'),
        I18n.t('activerecord.models.provider_group.one'),
        I18n.t('activerecord.attributes.plan.ceil_down'),
        I18n.t('activerecord.attributes.plan.ceil_up'),
        I18n.t('activerecord.attributes.contract.ip'),
        #I18n.t('activerecord.attributes.contract.forwarded_ports'),
        I18n.t('activerecord.attributes.contract.state'),
        I18n.t('activerecord.attributes.contract.ceil_dfl_percent'),
        I18n.t('activerecord.attributes.contract.public_forwarded_ports'),
        I18n.t('activerecord.attributes.contract.private_forwarded_ports'),
        I18n.t('activerecord.attributes.contract.mac_address'),
        I18n.t('activerecord.attributes.contract.node'),
        I18n.t('activerecord.attributes.contract.cpe'),
        I18n.t('activerecord.attributes.traffic.data_count')
      ] + plugins_columns

      # data rows
      _contracts.each do |c|
        c.create_traffic_for_this_period
        c.reload
        csv << [
          c.id,
          I18n.l(c.created_at.to_date),
          c.client.name,
          c.client.id,
          c.client.external_client_number,
          c.client.national_identification_number,
          c.client.email,
          c.client.address,
          c.client.phone,
          c.client.phone_mobile,
          c.client.details,
          c.plan.name,
          c.plan.provider_group.name,
          c.plan.ceil_down,
          c.plan.ceil_up,
          c.ip,
          #c.forwarded_ports.collect{ |fp| "[#{fp.provider.name}]#{fp.public_port}=>#{fp.private_port}" }.join("|"),
          I18n.t("aasm.contract." + c.state),
          c.ceil_dfl_percent,
          c.forwarded_ports.collect(&:public_port).join(", "),
          c.forwarded_ports.collect(&:private_port).join(", "),
          c.mac_address,
          c.node,
          c.cpe,
          c.current_traffic.data_count
        ] + plugins_rows(c)
      end
    end
  end

  def self.plugins_columns
    []
  end

  def self.plugins_rows contract
    []
  end

  def is_online?
    is_connected? ? I18n.t("messages.contract.connected") : I18n.t("messages.contract.not_connected")
  end

  def data_count_for_last_year
    dates = []
    datas = []
    _traffics = Traffic.for_contract(self.id).for_date(Date.new(Date.today.year, Date.today.month, Configuration.first.day_of_the_beginning_of_the_period) - 12.month)
    _traffics.each do |traffic|
      dates << traffic.from_date.strftime("%m-%Y")
      datas << traffic.data_count
    end
    [dates, datas]
  end

def ip_addr
  require "ipaddr"
  IPAddr.new(ip)
end

  # this will be overriden by bw changing plug-ins as time_modifiers and data_accounting
  def bandwidth_rate
    1
  end

  def do_per_contract_prios_tc(parent_mayor, parent_minor, iface, direction, action, _plan)
    tc_rules =[]
    mask = "0000ffff"
    ceil = _plan["ceil_" + direction] * bandwidth_rate
    rate = _plan.send("rate_" + direction) * bandwidth_rate
    rate = 1 if rate <= 0

    #padre
    tc_rules << "##{client.name} - IP: #{ip} ID: #{id} KLASS_NUMBER: #{class_hex}"
    tc_rules << "class #{action} dev #{iface} parent #{parent_mayor}:#{parent_minor} classid #{parent_mayor}:#{class_hex} hfsc ls m2 #{rate}kbit ul m2 #{ceil}kbit"
    #hijos
    #prio1
    tc_rules << "class #{action} dev #{iface} parent #{parent_mayor}:#{class_hex} classid #{parent_mayor}:#{class_prio1_hex} " +
            "est 1sec 5sec hfsc rt m1 #{rate}kbit d 50ms m2 #{rate/2}kbit ls m1 #{ceil} d 50ms m2 #{ceil/2}kbit"
    tc_rules << "filter #{action} dev #{iface} parent #{parent_mayor}: protocol all prio 200 handle 0x#{mark_prio1_hex}/0x#{mask} fw classid #{parent_mayor}:#{class_prio1_hex}"
    tc_rules << "qdisc #{action} dev #{iface} parent #{parent_mayor}:#{class_prio1_hex} sfq perturb 10"

    #prio2
    tc_rules << "class #{action} dev #{iface} parent #{parent_mayor}:#{class_hex} classid #{parent_mayor}:#{class_prio2_hex} " +
            "est 1sec 5sec hfsc ls m2 #{ceil}kbit"
    tc_rules << "filter #{action} dev #{iface} parent #{parent_mayor}: protocol all prio 200 handle 0x#{mark_prio2_hex}/0x#{mask} fw classid #{parent_mayor}:#{class_prio2_hex}"
    tc_rules << "qdisc #{action} dev #{iface} parent #{parent_mayor}:#{class_prio2_hex} sfq perturb 10"

    #prio3
    tc_rules << "class #{action} dev #{iface} parent #{parent_mayor}:#{class_hex} classid #{parent_mayor}:#{class_prio3_hex} " +
            "est 1sec 5sec hfsc ls m1 #{ceil * ceil_dfl_percent / 100 / 10}kbit d 3s m2 #{ceil * ceil_dfl_percent / 100}kbit ul m2 #{ceil * ceil_dfl_percent / 100}kbit"
    tc_rules << "filter #{action} dev #{iface} parent #{parent_mayor}: protocol all prio 200 handle 0x#{mark_prio3_hex}/0x#{mask} fw classid #{parent_mayor}:#{class_prio3_hex}"
    tc_rules << "qdisc #{action} dev #{iface} parent #{parent_mayor}:#{class_prio3_hex} sfq perturb 10"
  end

  def rules_for_up_data_counting
    macrule = (Configuration.filter_by_mac_address and mac_address.present?) ? "-m mac --mac-source #{mac_address}" : ""
    [ ":count-up.#{ip_addr.to_cidr} -",
      "-A count-up.#{ip_addr.to_cidr} #{macrule} -s #{ip} -m comment --comment \"data-count-#{ip}-up-data_count\"" ]
  end

  def rules_for_down_data_counting
    [ ":count-down.#{ip_addr.to_cidr} -",
      "-A count-down.#{ip_addr.to_cidr} -d #{ip} -m comment --comment \"data-count-#{ip}-down-data_count\"" ]
  end

  def rules_for_enabled
    macrule = (Configuration.filter_by_mac_address and !mac_address.blank?) ? "-m mac --mac-source #{mac_address}" : ""
    [ ":enabled.#{ip_addr.to_cidr} -", "-A enabled.#{ip_addr.to_cidr} #{macrule} -s #{ip} -j ACCEPT" ]
  end

  def rules_for_enabled
    macrule = (Configuration.filter_by_mac_address and !mac_address.blank?) ? "-m mac --mac-source #{mac_address}" : ""
    [ ":enabled.#{ip_addr.to_cidr} -", "-A enabled.#{ip_addr.to_cidr} #{macrule} -s #{ip} -j ACCEPT" ]
  end

  def rules_for_mark_provider
    [ ":mark.prov.#{ip_addr.to_cidr} -",
      "-A mark.prov.#{ip_addr.to_cidr} -s #{ip} -j MARK --set-mark 0x#{mark_provider}/0x00ff0000",
      "-A mark.prov.#{ip_addr.to_cidr} -s #{ip} -j ACCEPT" ]
  end

  def mark_provider
    if not public_address.nil?
      public_address.addressable.mark_hex
    elsif not unique_provider.nil?
      # marko los contratos que salen por un único provider
      unique_provider.mark_hex
    else
      plan.provider_group.mark_hex
    end
  end

  private

  #Please i need refactor
  def strip_whitespace
    self.tcp_prio_ports = self.tcp_prio_ports.strip unless self.tcp_prio_ports.nil?
    self.udp_prio_ports = self.udp_prio_ports.strip unless self.udp_prio_ports.nil?
    self.prio_protos = self.prio_protos.strip unless self.prio_protos.nil?
    self.prio_helpers = self.prio_helpers.strip unless self.prio_helpers.nil?
  end

end
