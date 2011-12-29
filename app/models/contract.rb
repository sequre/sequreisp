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
  FILE_SERVICES = RAILS_ROOT + "/db/files/valid_services"
  FILE_PROTOCOLS = RAILS_ROOT + "/db/files/valid_protocols"
  FILE_HELPERS = RAILS_ROOT + "/db/files/valid_helpers"
  acts_as_audited :except => [:netmask,
                              :queue_down_prio, :queue_up_prio, :queue_down_dfl, :queue_up_dfl,
                              :consumption_down_prio, :consumption_up_prio, :consumption_down_dfl, :consumption_up_dfl]
  belongs_to :client
  belongs_to :plan
  
  has_many :forwarded_ports, :dependent => :destroy
  accepts_nested_attributes_for :forwarded_ports, :reject_if => :all_blank, :allow_destroy => true
  has_one :klass, :dependent => :nullify
  has_one :provider_group, :through => :plan
  belongs_to :public_address, :class_name => 'Address', :conditions => "addressable_id is not null and addressable_type = 'provider'"
  belongs_to :proxy_arp_interface, :class_name => 'Interface', :conditions => "kind = 'lan'"
  belongs_to :unique_provider, :class_name => 'Provider'

  named_scope :enabled, :conditions => { :state => "enabled" }
  named_scope :not_disabled, :conditions => "state != 'disabled'"

  #este se usa para generar las reglas, ordena por netmask para asegurarse que las redes más grandes queden al final
  named_scope :descend_by_netmask, :order => "CAST(INET_ATON(netmask) AS UNSIGNED) DESC, CAST(INET_ATON(SUBSTRING_INDEX(ip, '/', 1)) AS UNSIGNED) ASC"

  named_scope :ascend_by_ip_custom, :order => "CAST(INET_ATON(SUBSTRING_INDEX(contracts.ip, '/', 1)) AS UNSIGNED) ASC, CAST(INET_ATON(contracts.netmask) AS UNSIGNED) ASC"
  named_scope :descend_by_ip_custom, :order => "CAST(INET_ATON(SUBSTRING_INDEX(contracts.ip, '/', 1)) AS UNSIGNED) DESC, CAST(INET_ATON(contracts.netmask) AS UNSIGNED) DESC"

  include ModelsWatcher
  watch_fields :ip, :plan_id, :mac_address, :ceil_dfl_percent, :state,
               :tcp_prio_ports, :udp_prio_ports, :prio_protos, :prio_helpers,
               :transparent_proxy, :proxy_arp, :proxy_arp_interface_id, :public_address_id,
               :unique_provider_id
  watch_on_destroy

  validates_presence_of :ip, :ceil_dfl_percent, :client, :plan
  validates_presence_of :proxy_arp_interface, :if => Proc.new { |c| c.proxy_arp } 

  validates_format_of :ip, :with => /^([12]{0,1}[0-9]{0,1}[0-9]{1}\.){3}[12]{0,1}[0-9]{0,1}[0-9]{1}(\/[123]{0,1}[0-9]{1}){0,1}$/, :allow_blank => true
  validates_format_of :tcp_prio_ports, :udp_prio_ports, :prio_protos, :prio_helpers, :with => /^([0-9a-z-]+(:[0-9]+)*,)*[0-9a-z-]+(:[0-9]+)*$/, :allow_blank => true
  validates_format_of :mac_address, :with => /^([0-9A-Fa-f]{2}\:){5}[0-9A-Fa-f]{2}$/, :allow_blank => true

  validates_numericality_of :ceil_dfl_percent, :only_integer => true, :greater_than => 0, :less_than_or_equal_to => 100

  validates_uniqueness_of :ip, :allow_nil => true, :allow_blank => true

  validate :state_should_be_included_in_the_list

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
  
  def ip_is_single_host?
    netmask == "255.255.255.255"
  end

  def validate_in_range_or_in_file(attr, min, max, file)
    valid_services= IO.readlines(file).collect{ |i| i.chomp } rescue [] 
    invalid_values = []
    if not self[attr].nil?
      self[attr].split(/,|:/).each do |i|
        is_integer = Integer(i) rescue false
        unless (is_integer and i.to_i > 0 and i.to_i < 65536) or valid_services.include?(i)
          invalid_values << i
        end
      end
      if not invalid_values.empty? 
        errors.add(attr, I18n.t('validations.contract.in_range_or_in_file_invalid', :invalid_values => invalid_values.join(",")))
      end
    end
  end

  def validate
    if not ip.blank?
      # Address tiene las ips de las interfaces y los  proveedores
      if Address.find_by_ip(ip) or Provider.find_by_ip(ip)
        errors.add(:ip, I18n.t('validations.ip_already_in_use'))
      end
    end
    if not tcp_prio_ports.blank?
      validate_in_range_or_in_file(:tcp_prio_ports, 0,65536, FILE_SERVICES)
    end
    if not udp_prio_ports.blank?
      validate_in_range_or_in_file(:udp_prio_ports, 0,65536, FILE_SERVICES)
    end
    if not prio_protos.blank?
      validate_in_range_or_in_file(:prio_protos, -1,256, FILE_PROTOCOLS)
    end
    if not prio_helpers.blank?
      validate_in_range_or_in_file(:prio_helpers, 0, 0, FILE_HELPERS)
    end
    if not plan_id.nil?
      new_plan = Plan.find(plan_id)
      remaining_rate_down = new_plan.provider_group.remaining_rate_down
      remaining_rate_up = new_plan.provider_group.remaining_rate_up
      if plan_id_changed? and not plan_id_was.nil?
        old_plan = Plan.find(plan_id_was)
        if old_plan.provider_group_id == new_plan.provider_group_id
          remaining_rate_down += old_plan.rate_down
          remaining_rate_up += old_plan.rate_up
        end
      end
      logger.debug("plan: #{plan.name} plan_id:#{plan_id} new_plan:#{new_plan.name}")
      if new_plan.rate_down > remaining_rate_down
        errors.add(:plan, I18n.t('validations.plan.not_enough_down_bandwidth_in_this_plan'))
      end
      if new_plan.rate_up > remaining_rate_up
        errors.add(:plan, I18n.t('validations.plan.not_enough_up_bandwidth_in_this_plan'))
      end
    end
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
    #if proxy_arp
    #  if proxy_arp_provider.nil?
    #    errors.add(:ip, I18n.t('validations.contract.proxy_arp_ip_does_not_belongs_to_plan'))
    #  end
    #end
  end

  include OverflowCheck
  before_save :check_integer_overflow  
  before_create :bind_klass

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
    self.klass = Klass.find(:first, :conditions => "contract_id is null")
    raise "TODO nos quedamos sin clases!" if self.klass.nil?
  end
  
  after_update :queue_update_commands
  after_destroy :queue_destroy_commands
  
  def queue_update_commands
    cq = QueuedCommand.new 
    if proxy_arp_changed? 
      if proxy_arp_was
        _interface = Interface.find proxy_arp_interface_id_was
        cq.command += "arp -i #{_interface.name} -d #{ip_was}"
      end
    elsif proxy_arp and proxy_arp_interface_id_changed?
      _interface = Interface.find proxy_arp_interface_id_was
      cq.command += "arp -i #{_interface.name} -d #{ip_was}"
    end
    cq.save if not cq.command.empty?
  end

  def queue_destroy_commands
    cq = QueuedCommand.new 
    if proxy_arp
      cq.command += "arp -i #{proxy_arp_interface.name} -d #{ip}"
    end
    cq.save if not cq.command.empty?
  end

  #AASM conf http://github.com/rubyist/aasm
  include AASM
  aasm_column :state
  aasm_initial_state :enabled
  aasm_state :enabled
  aasm_state :disabled

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

  def proxy_arp_provider
    begin
      c_ip = IP.new self.ip
      provider=nil
      Plan.find(plan_id).provider_group.providers.each do |p|
        p_ip = IP.new "#{p.ip}/#{p.netmask_suffix}"
        provider = p if (p_ip.to_i & p_ip.netmask.to_i) == (c_ip.to_i & p_ip.netmask.to_i)
        p.addresses.each do |a|
          provider = p if (a.ruby_ip.to_i & a.ruby_ip.netmask.to_i) == (c_ip.to_i & p_ip.netmask.to_i)
        end 
      end
      provider
    rescue
      nil
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
  def mark_hex
    self.klass.number.to_s(16)
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
  def transparent_proxy?
    # Habilitable por plan y reescribible por cliente
    # Hay un safe global de emergencia por si se rompre el proxy
    enabled = case self.transparent_proxy
      when "true"
        true
      when "false"
        false
      else 
        self.plan.transparent_proxy
    end
    enabled and Configuration.transparent_proxy
  end
  def instant_rate_down
    return rand(plan.ceil_down)*1024 if SequreispConfig::CONFIG["demo"]
    instant_rate SequreispConfig::CONFIG["ifb_down"]
    
  end
  def instant_rate_up
    return rand(plan.ceil_up)*1024/2 if SequreispConfig::CONFIG["demo"]
    instant_rate SequreispConfig::CONFIG["ifb_up"]
  end

  def instant_rate(iface)
    #return rand(plan.ceil_down)
    match = false
    rate = 0
    unit = ""
    IO.popen("/sbin/tc -s class show dev #{iface}", "r") do |io|
      io.each do |line|
        match = true if (line =~ /class htb \w+:#{class_hex} /) != nil
        if match and (line =~ /^ rate (\d+)(\w+) /) != nil
          rate = $~[1].to_i
          unit = $~[2]
          break
        end
      end
    end
    # from tc manpage (s/unit)
    # kbps   Kilobytes per second
    # mbps   Megabytes per second
    # kbit   Kilobits per second
    # mbit   Megabits per second
    # bps or a bare number
    #        Bytes per second
    case unit.downcase
    when "kbps"
      rate *= 1024*8
    when "mbps"
      rate *= 1024*1024*8
    when "kbit"
      rate *= 1024
    when "mbit"
      rate *= 1024*1024
    when "bit"
      rate
    else # "bps" or a bare number
      #TODO nunca va a caer aca x "bare number" con w+ como condición de la regexp
      rate *= 8
    end
  end
  def self.transparent_proxy_for_select
    [
    [I18n.t("selects.contract.transparent_proxy.true"),"true"],
    [I18n.t("selects.contract.transparent_proxy.default"), "default"],
    [I18n.t("selects.contract.transparent_proxy.false"),"false"]
    ]
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

  def mangle_chain(prefix)
    if Configuration.iptables_tree_optimization_enabled?
      suffix = netmask_suffix
      value = 28
      value -= 4 while suffix < value and value > 16
      _ip = IP.new("#{ip.gsub(/\/.*/, "")}/#{value}").network.to_s
      "sq.#{prefix}.#{_ip}"
    else
      "sequreisp.#{prefix}"
    end
  end

  def auditable_name
    "#{self.class.human_name}: #{client.name} (#{ip})"
  end

  def self.slash_16_networks
    Contract.all(:select => :ip).collect { |c| c.ip.split(".")[0,2].join(".") + ".0.0/16" }.uniq
  end
end
