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
  watch_fields :contract_id, :provider_id, :public_init_port, :private_port, :tcp, :udp
  watch_on_destroy

  validates_presence_of :provider, :public_init_port
  validates_presence_of :private_port, :unless => :end_port?
  validates_numericality_of :public_init_port, :private_port, :greater_than => 0, :less_than_or_equal_to => 65535, :only_integer => true, :allow_blank => true
  validate :uniqueness_of_public_port_on_provider
  validate :public_port_cant_be_on_the_prohibited_list

  named_scope :ports_in_use, lambda { |prov_id| 
             {:conditions => "provider_id = #{prov_id}"}
  }

  attr_accessor :is_a_range

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
    "[#{provider.name}]: #{public_or_init_port}(#{proto})->#{private_port}"
  end

  def public_port_cant_be_on_the_prohibited_list
    ports_to_forward = self.get_ports.to_a 
    prohibited_ports = ProhibitedForwardPort.prohibited_ports_to_forward(self.tcp, self.udp).collect(&:port)
    forbidden_ports = prohibited_ports & ports_to_forward 
    unless forbidden_ports.empty?
      errors.add(:public_port, I18n.t("validations.forwarded_port.public_port_cant_be_on_the_prohibited_list", :ports => forbidden_ports.join(', ') ))
    end
  end

  def auditable_name
    "#{self.class.human_name}: #{contract.ip} - #{provider.name}(#{public_or_init_port}->#{private_port}#{',T' if tcp}#{',U' if udp})"
  end

  def auditable_model_to_show
    contract rescue nil
  end

  def public_or_init_port
    self.end_port ? "#{public_init_port}:#{end_port}" : self.public_init_port
  end
	
  def private_port_wrapper
    self.end_port ? "" : ":#{self.private_port}"
  end

  def get_ports
    self.end_port? ? (self.public_init_port..self.end_port) : self.public_init_port
  end

  def uniqueness_of_public_port_on_provider
    fp_in_use = ForwardedPort.ports_in_use(self.provider_id) 
    fp_in_use.each do |port|
      forbidden_ports = port.get_ports.to_a & self.get_ports.to_a 	
      unless forbidden_ports.empty?
        errors.add(:public_port, I18n.t(forbidden_ports.count > 1 ? "error_messages.ports_already_taken" : "error_messages.port_already_taken", :port => forbidden_ports.join(', ') , :ip => port.contract.ip, :contract_id => port.contract.id ))
      end
    end
  end
end
