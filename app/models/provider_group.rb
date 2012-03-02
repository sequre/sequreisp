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

class ProviderGroup < ActiveRecord::Base
  acts_as_audited
  has_many :plans, :dependent => :nullify
  has_many :providers, :dependent => :nullify, :include => :interface
  has_one :klass, :as => :klassable, :class_name => "ProviderKlass", :dependent => :nullify
  named_scope :with_klass, :include => [:klass]
  has_many :contracts, :through => :plans

  include ModelsWatcher
  watch_fields :state

  validates_presence_of :name 
  validates_length_of :name, :in => 3..128
  validates_uniqueness_of :name
 
  include OverflowCheck
  before_save :check_integer_overflow
  before_create :bind_klass
  
  #AASM conf http://github.com/rubyist/aasm
  include AASM
  aasm_column :state
  aasm_initial_state :enabled
  aasm_state :enabled
  aasm_state :disabled

  aasm_event :enable do
    transitions :from => [:disabled], :to => :enabled
  end
  aasm_event :disable do
    transitions :from => [:enabled], :to => :disabled
  end
  
  def self.aasm_states_for_select
    AASM::StateMachine[self].states.map { |state| [I18n.t("aasm.provider_group.#{state.name.to_s}"),state.name.to_s] }
  end
 
  def bind_klass
    self.klass = ProviderKlass.find(:first, :conditions => "klassable_id is null")
    raise "TODO nos quedamos sin clases!" if self.klass.nil?
  end

  def default_route
    online_providers = self.providers.enabled.ready.online
    case online_providers.count
    when 0
      "" 
    when 1
      p = online_providers.first
      "default via #{p.gateway} dev #{p.link_interface}  proto static onlink"
    else
      route = ""
      online_providers.each do |p|
        route += "  nexthop via #{p.gateway}  dev #{p.link_interface} weight #{p.weight} onlink"
      end
      "default  proto static #{route}"
    end
  end
  def rate_down
    total=0
    providers.enabled.each do |p|
      total+=p.rate_down
    end
    total
  end
  def remaining_rate_down(exclude_id=nil)
    remaining = rate_down
    plans.each do |plan|
      if plan.rate_down == 0
        #24bits reservados por cliente
        remaining -= (plan.contracts.count * 0.024)
      else 
        remaining -= (plan.contracts.count * plan.rate_down)
      end
    end
    remaining
  end
  def rate_up
    total=0
    providers.enabled.each do |p|
      total+=p.rate_up
    end
    total
  end
  def remaining_rate_up(exclude_id=nil)
    remaining = rate_up
    plans.each do |plan|
      if plan.rate_up == 0
        #24bits reservados por cliente
        remaining -= (plan.contracts.count * 0.024)
      else 
        remaining -= (plan.contracts.count * plan.rate_up)
      end
    end
    remaining
  end
  def table
    self.klass.number
  end
  def class_hex
    self.klass.number.to_s(16)    
  end
  def mark_hex
    (self.klass.number << 16).to_s(16)
  end
  def proxy_bind_ip
    # 192.0.2.0/24 reserved for TEST-NET-1 [RFC5737]
    "192.0.2.#{klass.number}"
  end
  def instant_rate
    rate = {}
    if SequreispConfig::CONFIG["demo"]
      rate[:down] = rand(rate_down)*1024
      rate[:up] = rand(rate_up)*1024/2
    else
      rx = tx = 0 
      rx2 = tx2 = 0 
      providers.enabled.each do |p| 
        rx += p.interface.rx_bytes
        tx += p.interface.tx_bytes
      end
      sleep 2
      providers.enabled.each do |p| 
        rx2 += p.interface.rx_bytes
        tx2 += p.interface.tx_bytes
      end
      rate[:down] = (rx2-rx)*8*1000/1024/2
      rate[:up] = (tx2-tx)*8*1000/1024/2
    end
    rate
  end
  def auditable_name
    "#{self.class.human_name}: #{name}"
  end
  def concurrency_index_down
    begin
      rate_down * 100 / contracts.all(:include => :plan).collect{ |c| c.plan.ceil_down }.sum
    rescue
      0
    end
  end
  def concurrency_index_up
    begin
      rate_up * 100 / contracts.all(:include => :plan).collect{ |c| c.plan.ceil_up }.sum
    rescue
      0
    end
  end
end
