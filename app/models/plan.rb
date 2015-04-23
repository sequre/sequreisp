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

class Plan < ActiveRecord::Base

  CIR_STRATEGY_REUSE = 'reuse'
  CIR_STRATEGY_PERCENTAGE = 'percentage'
  CIR_STRATEGY_PLAN_TOTAL = 'plan_total'
  CIR_STRATEGY_AUTOMATIC = 'automatic'

  acts_as_audited
  attr_accessor :cir_reuse

  include ModelsWatcher
  watch_fields :provider_group_id, :ceil_down, :ceil_up, :total_cir_down, :total_cir_up, :cir, :long_download_max, :long_upload_max

  has_many :contracts, :dependent => :destroy, :include => :klass
  has_many :providers, :through => :provider_group
  belongs_to :provider_group

  validates_uniqueness_of :name
  validates_presence_of :name, :provider_group, :ceil_down, :ceil_up
  validates_presence_of :cir_reuse, :if => lambda { |p| p.cir_strategy == CIR_STRATEGY_REUSE }
  validates_presence_of :cir, :if => lambda { |p| p.cir_strategy == CIR_STRATEGY_PERCENTAGE }
  validates_presence_of :total_cir_down, :total_cir_up, :if => lambda { |p| p.cir_strategy == CIR_STRATEGY_PLAN_TOTAL }
  validates_length_of :name, :in => 3..128
  validates_numericality_of :ceil_down, :ceil_up, :only_integer => true, :allow_nil => true, :greater_than => 0
  validates_numericality_of :long_download_max, :long_upload_max, :only_integer => true, :greater_than_or_equal_to => 0, :less_than => 4294967295
  validates_numericality_of :cir, :greater_than => 0, :less_than_or_equal_to => 1, :allow_nil => true

  before_save :pass_cir_reuse_to_percentage, :if => lambda { |p| p.cir_strategy == CIR_STRATEGY_REUSE }


  def pass_cir_reuse_to_percentage
    self.cir = self.cir_reuse
  end

  def cir_up
    @cached_cir_up ||=
    case cir_strategy
    when CIR_STRATEGY_AUTOMATIC
      _cir = provider_group.rate_up.to_f / provider_group.ceil_up
      [1, ((_cir.infinite? ? 1.0 : _cir) rescue 0.01).round(2)].min
    when CIR_STRATEGY_PLAN_TOTAL
      [1 , (total_cir_up.to_f / (ceil_up * contracts_count) rescue 0.01).round(2)].min
    else
      cir
    end
  end

  def cir_down
    @cached_cir_down ||=
    case cir_strategy
    when CIR_STRATEGY_AUTOMATIC
      _cir = (provider_group.rate_down.to_f / provider_group.ceil_down)
      [1, ((_cir.infinite? ? 1.0 : _cir) rescue 0.01).round(2)].min
    when CIR_STRATEGY_PLAN_TOTAL
      [1 , (total_cir_down.to_f / (ceil_down * contracts_count) rescue 0.01).round(2)].min
    else
      cir
    end
  end

  def cir_total_up
    @cached_cir_total_up ||=
    if cir_strategy == CIR_STRATEGY_PLAN_TOTAL
      total_cir_up
    else
      (ceil_up * cir_up * contracts_count).to_i
    end
  end

  def cir_total_down
    @cached_cir_total_down ||=
    if cir_strategy == CIR_STRATEGY_PLAN_TOTAL
      total_cir_down
    else
      (ceil_down * cir_down * contracts_count).to_i
    end
  end

  def contracts_count
    contracts.select { |contract| contract.state != 'disabled' }.count
  end

  def cir_up_real
    provider_group.cir_total_up * cir_up / provider_group.rate_up
  end

  def cir_down_real
    provider_group.cir_total_down * cir_down / provider_group.rate_down
  end

  def rate_up
    ceil_up * cir_up_real
  end

  def rate_down
    ceil_down * cir_down_real
  end

  def default_value_for_cir_reused
    cir || 1.0
  end

  def long_download_max_to_bytes
    long_download_max * 1024
  end
  def long_upload_max_to_bytes
    long_upload_max * 1024
  end
  def auditable_name
    "#{self.class.human_name}: #{name}"
  end
end
