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

  validate :name_cannot_be_changed

  def validate
    if kind_changed? and kind_was == "wan" and provider
      errors.add(:kind, I18n.t('validations.interface.unable_to_change_kind'))
    end
  end

  before_save :if_vlan
  before_save :if_wan

  after_update :queue_update_commands
  after_destroy :queue_destroy_commands

  def name_cannot_be_changed
    errors.add(:name, I18n.t('validations.interface.name_cannot_be_changed')) if not new_record? and name_changed?
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
    if SequreispConfig::CONFIG["demo"]
      if kind == "lan"
        # en lan el down de los providers es el up
        rate[:down] = rand(ProviderGroup.all.collect(&:rate_up).sum)*1024/2
        rate[:up] = rand(ProviderGroup.all.collect(&:rate_down).sum)*1024
      else
        rate[:down] = rand(provider.rate_down)*1024 rescue 0
        rate[:up] = rand(provider.rate_up)*1024/2 rescue 0
      end
    else
      rx = rx_bytes
      tx = tx_bytes
      sleep 2
      rate[:down] = (rx_bytes-rx)*8*1000/1024/2
      rate[:up] = (tx_bytes-tx)*8*1000/1024/2
    end
    rate
  end
  def physical_link
    self.vlan? ? vlan_interface.physical_link : read_attribute(:physical_link)
  end
  def status
    self.physical_link ? "up" : "down"
  end
  def status_class
    self.physical_link ? "online" : "offline"
  end
  def auditable_name
    "#{self.class.human_name}: #{name}"
  end
  def self.scan
    #TODO Support other distros
    begin
      File.open("/etc/udev/rules.d/70-persistent-net.rules").readlines.join.scan(/NAME="([^"]+)"/).flatten
    rescue => e
      Rails.logger.error e.inspect
    end
  end
  def vlan_interface_collection
    new_record? ? Interface.find(:all, :conditions => ["vlan = 0"]) : Interface.find(:all, :conditions => ["vlan = 0 and id != ?", id])
  end
end
