class Iproute < ActiveRecord::Base
  acts_as_audited
  belongs_to :interface
  include ModelsWatcher
  watch_fields :dst_address, :gateway, :interface_id
  watch_on_destroy

  include IpAddressCheck
  validate_ip_format_of :dst_address, :with_netmask => true
  validate_ip_format_of :gateway
  validates_uniqueness_of :dst_address

  validates_presence_of :dst_address
  validates_presence_of :gateway, :if => Proc.new { |i| i.interface_id.nil? }
  validates_presence_of :interface, :if => Proc.new { |i| not i.gateway.present? }

  validate :dst_address_without_netmask, :if => "dst_address_changed?"
  def dst_address_without_netmask
    _dst_address = IP.new(dst_address)
    # check that the mask is set only for networks
    if _dst_address.mask > 0 and _dst_address != _dst_address.network
      errors.add(:dst_address, I18n.t('validations.contract.do_not_set_mask_if_is_not_a_network'))
    end
  end

#  validate :presence_of_gateway_or_interface_id

#  def presence_of_gateway_or_interface_id
#    if gateway.empty? and interface_id.nil?
#    end
#  end
  def route
    via = ""
    via += " via #{gateway}" if gateway.present?
    via +=" dev #{interface.name}" if not interface.nil?
    "#{dst_address}#{via}"
  end
  def route_was
    interface_was = Interface.find(interface_id_was) rescue nil
    via = ""
    via += " via #{gateway_was}" if gateway_was.present?
    via +=" dev #{interface_was.name}" if not interface_was.nil?
    "#{dst_address_was}#{via}"
  end

  after_update :queue_update_commands
  after_destroy :queue_destroy_commands

  def queue_update_commands
    cq = QueuedCommand.new
    if dst_address_changed? or gateway_changed? or interface_id_changed?
      cq.command += "ip ro del #{route_was}"
    end
    cq.save if not cq.command.empty?
  end

  def queue_destroy_commands
    cq = QueuedCommand.new
    cq.command += "ip ro del #{route}"
    cq.save if not cq.command.empty?
  end

  def auditable_name
    "#{self.class.human_name}: #{dst_address}"
  end
end
