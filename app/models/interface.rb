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

class Interface < ActiveRecord::Base
  require 'sequreisp_logger'
  DEFAULT_TX_QUEUE_LEN_FOR_VLAN = 1000
  DEFAULT_TX_QUEUE_LEN_FOR_IFB = 1000
  acts_as_audited
  belongs_to :vlan_interface, :class_name => "Interface", :foreign_key => "vlan_interface_id"
  has_many :vlan_interfaces, :class_name => "Interface", :foreign_key => "vlan_interface_id", :dependent => :destroy
  has_one :provider, :dependent => :nullify
  has_many :addresses, :as => :addressable, :class_name => "Address", :dependent => :destroy
  has_many :contracts, :dependent => :nullify, :foreign_key => "proxy_arp_interface_id"
  has_many :iproutes, :dependent => :destroy

  #accepts_nested_attributes_for :addresses, :reject_if => lambda { |a| a[:content].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :addresses, :reject_if => lambda { |a| a[:ip].blank? }, :allow_destroy => true

  include ModelsWatcher
  watch_fields :name, :vlan, :vlan_id, :vlan_interface_id, :kind
  watch_on_destroy

  validates_presence_of :vlan_interface, :vlan_id, :if => Proc.new { |p| p.vlan? }
  validates_presence_of :name, :if => Proc.new { |p| not p.vlan? }
  validates_uniqueness_of :vlan_id, :scope => :vlan_interface_id, :if => Proc.new { |p| p.vlan? }
  validates_numericality_of :vlan_id, :allow_nil => true, :only_integer => true, :greater_than => 1, :less_than => 4095
  validates_uniqueness_of :name
  validates_format_of :name, :with => /^[a-zA-Z0-9]+$/, :message => I18n.t("messages.interface.name_without_space"), :if => 'not vlan'
  validates_uniqueness_of :mac_address
  validate :uniqueness_mac_address_in_contracts, :if => 'kind == "lan"'

  validate :name_cannot_be_changed
  validate_on_create :interface_exist, :if => 'not vlan'
  validates_format_of :mac_address, :with => /^([0-9A-Fa-f]{2}\:){5}[0-9A-Fa-f]{2}$/, :allow_blank => true

  def validate
    if kind_changed? and kind_was == "wan" and provider
      errors.add(:kind, I18n.t('validations.interface.unable_to_change_kind'))
    end
  end

  before_save :if_vlan
  before_save :if_wan
  before_save :set_mac_address

  after_update :queue_update_commands
  after_destroy :queue_destroy_commands

  named_scope :only_lan, :conditions => { :kind => "lan" }
  named_scope :only_wan, :conditions => { :kind => "wan" }

  def uniqueness_mac_address_in_contracts
     if (contract = Contract.all(:conditions => { :mac_address => self.mac_address })).count > 0
      errors.add(:mac_address, I18n.t('validations.interface.mac_address_taken_in_contract', :contract_id => contract.first.id ) )
     end
  end

  def set_mac_address
    real_mac_address = Interface.which_is_real_mac_address(name, vlan?)
    if mac_address.present?
      generate_internal_mac_address if mac_address_changed? and (self.mac_address == real_mac_address) and vlan?
    else
      if vlan?
        generate_internal_mac_address
      else
        self.mac_address = real_mac_address
      end
    end
  end

  def name_cannot_be_changed
    errors.add(:name, I18n.t('validations.interface.name_cannot_be_changed')) if not new_record? and name_changed?
  end
  def interface_exist
    errors.add(:name, I18n.t('validations.interface.name_does_not_exist')) if not exist?
  end
  def queue_update_commands
    cq = QueuedCommand.new
    # el vlan_id y el vlan_interface_id si cambian se reflejan en el nombre
    # x eso me basta con chequear el nombre
    if name_changed? or kind_changed?
      cq.command += "ip address flush dev #{name_was};"
    end
    if vlan_changed? and vlan_was
      cq.command += "vconfig rem #{name_was};"
    end
    cq.save if not cq.command.empty?
  end

  def queue_destroy_commands
    cq = QueuedCommand.new
    cq.command += "ip address flush dev #{name};"
    if vlan?
      cq.command += "vconfig rem #{name};"
    end
    cq.save if not cq.command.empty?
  end

  def self.kinds_for_select
    [["WAN", "wan"],["LAN", "lan"]]
  end

  def if_vlan
    if vlan?
      self.name = "#{self.vlan_interface.name}.#{vlan_id}"
    else
      self.vlan_id = self.vlan_interface = nil
    end
  end
  def if_wan
    if kind == "wan"
      self.addresses.delete_all
    end
  end
  def rate_down
    0
  end
  def rate_up
    0
  end
  def rx_bytes
    File.open("/sys/class/net/#{name}/statistics/rx_bytes").read.chomp.to_i rescue 0
  end
  def tx_bytes
    File.open("/sys/class/net/#{name}/statistics/tx_bytes").read.chomp.to_i rescue 0
  end
  def instant_rate
    rate = {}
    if SequreispConfig::CONFIG["demo"] or Rails.env.development?
      if kind == "lan"
        # en lan el down de los providers es el up
        rate[:rate_down] = rand(ProviderGroup.all.collect(&:rate_up).sum)*1024/2
        rate[:rate_up] = rand(ProviderGroup.all.collect(&:rate_down).sum)*1024
      else
        rate[:rate_down] = rand(provider.rate_down)*1024 rescue 0
        rate[:rate_up] = rand(provider.rate_up)*1024/2 rescue 0
      end
    else
      rate[:rate_up] = $redis.hmget("interface:#{name}:rate_tx", "instant").first.to_i
      rate[:rate_down] = $redis.hmget("interface:#{name}:rate_rx", "instant").first.to_i
    end
    rate
  end
  def physical_link
    self.vlan? ? vlan_interface.physical_link : read_attribute(:physical_link)
  end
  def status
    self.current_physical_link ? "up" : "down"
  end
  def status_class
    self.current_physical_link ? "online" : "offline"
  end
  def auditable_name
    "#{self.class.human_name}: #{name}"
  end
  def self.scan
    #TODO Support other distros
    begin
      File.open("/etc/udev/rules.d/70-persistent-net.rules").readlines.join.scan(/NAME="([^"]+)"/).flatten
    rescue => e
      log_rescue("[Model][Interface][scan]", e)
      Rails.logger.error e.inspect
    end
  end
  def vlan_interface_collection
    new_record? ? Interface.find(:all, :conditions => ["vlan = 0"]) : Interface.find(:all, :conditions => ["vlan = 0 and id != ?", id])
  end
  def speed
    `sudo ethtool #{name} 2>/dev/null`.match("Speed: \(.*\)")[1] rescue "-"
  end
  def current_physical_link
    `ip link show dev #{name} 2>/dev/null`.scan(/state (\w+) /).flatten[0] == "UP" || `sudo mii-tool #{name} 2>/dev/null`.scan(/link ok/).flatten[0] == "link ok" || `sudo ethtool #{name} 2>/dev/null`.scan(/Link detected: yes/).flatten[0] == "Link detected: yes"
  end
  # Used by modules
  def self.lan_ip_addresses
    lan_ips = []
    self.only_lan.each { |lan_interface| lan_ips.concat(lan_interface.addresses.collect{ |address| address.ip }) }
    lan_ips
  end

  def exist?
    system "ip link show dev #{name} 1>/dev/null 2>/dev/null"
  end

  def mac_address_equal_to_real_mac?
    mac_address == (`ip li show dev #{name} 2>/dev/null`.match(/link\/ether ([0-9a-fA-F:]+)/)[1] rescue nil)
  end

  def self.which_is_real_mac_address(_name, vlan=false)
    _name = _name.split(".").first if vlan
    `ip li show dev #{_name} 2>/dev/null`.match(/link\/ether ([0-9a-fA-F:]+)/)[1] rescue nil
  end

  def generate_internal_mac_address
    #Always set locally administered and unicast, 02 first octet
    self.mac_address = (2**41 + self.id.to_i * (2**24) + vlan_id.to_i).to_s(16).rjust(12, "0").scan(/../).join(":")
  end

  def lan?
    kind == "lan"
  end

  def wan?
    kind == "wan"
  end
end
