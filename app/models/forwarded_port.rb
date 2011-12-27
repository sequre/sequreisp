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

class ForwardedPort < ActiveRecord::Base
  acts_as_audited
  
  belongs_to :contract
  belongs_to :provider

  include ModelsWatcher
  watch_fields :contract_id, :provider_id, :public_port, :private_port, :tcp, :udp
  watch_on_destroy

  validates_presence_of :provider, :public_port, :private_port
  validates_numericality_of :public_port, :private_port, :greater_than => 0, :less_than_or_equal_to => 65535, :only_integer => true, :allow_blank => true
  validates_uniqueness_of :public_port, :scope => :provider_id

  validate :public_port_cant_be_on_the_prohibited_list

  def validate
    #if !provider_id.nil? and !contract_id.nil?
    #  if Provider.find(provider_id).provider_group !=  Contract.find(contract_id).provider_group
    #    errors.add(:provider, I18n.t("validations.forwarded_port.provider_doesnt_belong_to_group_plan"))
    #  end
    #end
    if !tcp and !udp
      errors.add(:tcp, I18n.t("validations.forwarded_port.protocol_must_be_specified"))
    end
  end
  def to_s
    proto = (tcp? and udp?) ? "tcp/udp" : tcp? ? "tcp" : "udp"
    "[#{provider.name}]: #{public_port}(#{proto})->#{private_port}"
  end

  def public_port_cant_be_on_the_prohibited_list
    if ProhibitedForwardPort.exists? ["port = ? AND (tcp = ? OR udp = ?)", self.public_port, self.tcp, self.udp]
        errors.add(:public_port, I18n.t("validations.forwarded_port.public_port_cant_be_on_the_prohibited_list"))
    end
  end

  def auditable_name
    "#{self.class.human_name}: #{contract.ip} - #{provider.name}(#{public_port}->#{private_port}#{',T' if tcp}#{',U' if udp})"
  end
end
