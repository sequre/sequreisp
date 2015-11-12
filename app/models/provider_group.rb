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
  include ActionView::Helpers
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
  after_create :bind_klass

  #AASM conf http://github.com/rubyist/aasm
  include AASM
  aasm_column :state
  aasm_initial_state :enabled
  aasm_state :enabled rescue nil
  aasm_state :disabled rescue nil

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
    self.klass = ProviderKlass.find(:first, :conditions => "klassable_id is null", :lock => "for update")
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
    @cached_rate_down ||= providers.enabled.collect(&:rate_down).sum
    # total=0
    # providers.enabled.each do |p|
    #   total+=p.rate_down
    # end
    # total
  end
  # def remaining_rate_down(exclude_id=nil)
  #   remaining = rate_down
  #   plans.each do |plan|
  #     remaining -= (plan.contracts.count * plan.rate_down)
  #   end
  #   remaining
  # end
  def self.total_rate_down
    all.collect(&:rate_down).sum
  end

  def rate_up
    @cached_rate_up ||= providers.enabled.collect(&:rate_up).sum
    # total=0
    # providers.enabled.each do |p|
    #   total+=p.rate_up
    # end
    # total
  end
  # def remaining_rate_up(exclude_id=nil)
  #   remaining = rate_up
  #   plans.each do |plan|
  #     remaining -= (plan.contracts.count * plan.rate_up)
  #   end
  #   remaining
  # end
  def self.total_rate_up
    all.collect(&:rate_up).sum
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
  def instant
    instant = {:rx => [], :tx => []}
    providers.enabled.each do  |p|
      iface_instant = p.interface.instant
      instant[:rx] << iface_instant[:rx]
      instant[:tx] << iface_instant[:tx]
    end
    instant[:rx] = instant[:rx].transpose.map(&:sum)
    instant[:tx] = instant[:tx].transpose.map(&:sum)
    instant
  end
  def auditable_name
    "#{self.class.human_name}: #{name}"
  end
  def concurrency_index_down
    begin
      rate_down * 100 / ceil_up
    rescue
      0
    end
  end
  def concurrency_index_up
    begin
      rate_up * 100 / ceil_up
    rescue
      0
    end
  end
  def ceil_down
    @cached_ceil_down ||= contracts.not_disabled.all(:include => :plan).collect{ |c| c.plan.ceil_down }.sum
  end
  def ceil_up
    @cached_ceil_up ||= contracts.not_disabled.all(:include => :plan).collect{ |c| c.plan.ceil_up }.sum
  end

  def cir_total_up
    @cached_cir_total_up ||= plans.collect(&:cir_total_up).sum rescue 0
  end

  def cir_total_down
    @cached_cir_total_down ||= plans.collect(&:cir_total_down).sum rescue 0
  end
end
