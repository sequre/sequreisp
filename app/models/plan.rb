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
  has_many :contracts, :dependent => :destroy, :include => :klass
  has_many :providers, :through => :provider_group
  acts_as_audited
  belongs_to :provider_group

  attr_accessor :how_use_cir
  attr_accessor :cir_percentage
  attr_accessor :value_cir_re_used

  include ModelsWatcher
  watch_fields :provider_group_id, :ceil_down, :ceil_up, :total_cir_down, :total_cir_up, :cir_down, :cir_up, :burst_down, :burst_up, :long_download_max, :long_upload_max

  validates_uniqueness_of :name
  validates_presence_of :name, :provider_group, :ceil_down, :ceil_up
  validates_presence_of :value_cir_re_used, :if => "how_use_cir == 're_used'"
  validates_presence_of :cir_percentage, :if => "how_use_cir == 'percentage'"
  validates_presence_of :total_cir_down, :total_cir_up, :if => "how_use_cir == 'total_cir'"
  validates_length_of :name, :in => 3..128
  validates_numericality_of :ceil_down, :ceil_up, :only_integer => true, :allow_nil => true, :greater_than_or_equal_to => 0
  validates_numericality_of :burst_down, :burst_up, :only_integer => true, :greater_than_or_equal_to => 0
  validates_numericality_of :long_download_max, :long_upload_max, :only_integer => true, :greater_than_or_equal_to => 0, :less_than => 4294967295

  validate :ceil_down_different_to_zero
  validate :ceil_up_different_to_zero
  validate :cir_percentage_less_than

  before_save :set_cir_and_total_cir

  def cir_percentage_less_than
    errors.add(:cir_percentage, I18n.t('validations.plan.cir_percentage_different_to_zero')) if cir_percentage.to_f == 0
    errors.add(:cir_percentage, I18n.t('validations.plan.cir_percentage_less_than_to_one')) if cir_percentage.to_f >= 0
  end

  def set_total_cir
    self.total_cir_up = self.ceil_up * self.cir_up * contracts_count rescue 0
    self.total_cir_down = self.ceil_down * self.cir_down * contracts_count rescue 0
  end

  def set_cir_and_total_cir
    self.used_total_cir = false
    self.used_cir_percentage = false
    case how_use_cir
    when "percentage"
      self.used_cir_percentage = true
    when "total_cir"
      self.used_total_cir = true
    end
    set_cir
    set_total_cir unless used_total_cir
  end

  def set_cir
    if used_total_cir
      self.cir_up = self.total_cir_up / (self.ceil_up * contracts_count) rescue 0.0001
      self.cir_down = self.total_cir_down / (self.ceil_down * contracts_count) rescue 0.0001
    else
      if used_cir_percentage
        self.cir_up = self.cir_down = self.cir_percentage
      else
        self.cir_up = self.cir_down = self.value_cir_re_used
      end
    end
  end

  def contracts_count
    contracts.select { |contract| contract.state != 'disabled' }.count
  end

  def real_total_cir_up
    pg = provider_group
    [(pg.rate_down * total_cir_down / pg.total_cir_down), total_cir_up].min
  end

  def real_total_cir_down
    pg = provider_group
    [(pg.rate_up * total_cir_up / pg.total_cir_up), total_cir_down].min
  end

  def cir_factor_up
    real_total_cir_up / contracts_count
  end

  def cir_factor_down
    real_total_cir_down / contracts_count
  end

  def rate_up
    ceil_up * cir_up rescue 0
  end

  def rate_down
    ceil_down * cir_down rescue 0
  end

  def default_value_for_cir_reused
    cir_up || 1.0
  end

  def default_value_for_which_use_cir
    return "total_cir" if self.used_total_cir
    return "percentage" if self.used_cir_percentage
    "re_used"
  end

  def ceil_up_different_to_zero
    errors.add(:ceil_up, I18n.t('validations.plan.ceil_up_different_to_zero')) if ceil_up == 0
  end

  def ceil_down_different_to_zero
    errors.add(:ceil_down, I18n.t('validations.plan.ceil_down_different_to_zero')) if ceil_down == 0
  end

  def burst_down_to_bytes
    (burst_down / 8) * 1024
  end
  def burst_up_to_bytes
    (burst_up / 8) * 1024
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
