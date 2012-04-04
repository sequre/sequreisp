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

class Address < ActiveRecord::Base
  acts_as_audited

  belongs_to :addressable, :polymorphic => true
  has_one :contract, :dependent => :nullify, :foreign_key => "public_address_id"

  include ModelsWatcher
  watch_fields :ip, :netmask, :use_in_nat_pool, :addressable_id, :addressable_type
  watch_on_destroy

  validates_presence_of :ip, :netmask
  validates_format_of :netmask, :with => /^([12]{0,1}[0-9]{0,1}[0-9]{1}\.){3}[12]{0,1}[0-9]{0,1}[0-9]{1}$/, :allow_blank => true
  validates_uniqueness_of :ip

  include IpAddressCheck
  validate_ip_format_of :ip

  def validate
    if not ip.blank?
      # Address tiene las ips de las interfaces y los  proveedores
      if Provider.find_by_ip(ip) or Contract.find_by_ip(ip)
        errors.add(:ip, I18n.t('validations.ip_already_in_use'))
      end
    end
  end

  after_update :queue_update_commands
  after_destroy :queue_destroy_commands

  def queue_update_commands
    cq = QueuedCommand.new
    if ip_changed? or netmask_changed?
      case addressable_type
      when "Provider"
        cq.command += "ip address del #{ip_was}/#{netmask_was} dev #{addressable.interface.name}"
      when "Interface"
        cq.command += "ip address del #{ip_was}/#{netmask_was} dev #{addressable.name}"
      end
    end
    cq.save if not cq.command.empty?
  end

  def queue_destroy_commands
    cq = QueuedCommand.new
    case addressable_type
    when "Provider"
      cq.command += "ip address del #{ip}/#{netmask} dev #{addressable.interface.name}"
    when "Interface"
      cq.command += "ip address del #{ip}/#{netmask} dev #{addressable.name}"
    end
    cq.save if not cq.command.empty?
  end

  def name
    case self.addressable_type
    when "Provider"
      prefix = ""
      prefix += "#{I18n.t('activerecord.attributes.address.free_ip_prefix') if !self.contract}"
      prefix += "#{I18n.t('activerecord.attributes.address.nat_pool_ip_prefix') if !self.use_in_nat_pool}"
      "#{prefix + " " if not prefix.blank?}#{self.ip} - #{addressable.provider_group.name}"
    else
        ""
    end
  end

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
  def ruby_ip
    IP.new("#{self.ip}/#{netmask_suffix}") rescue nil
  end
  def network
    ruby_ip.network.to_s rescue nil
  end

  def auditable_name
    "#{self.class.human_name}: #{addressable.auditable_name} #{ip}"
  end
end
