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
  acts_as_audited
  belongs_to :provider_group

  include ModelsWatcher
  watch_fields :provider_group_id, :rate_down, :ceil_down, :rate_up, :ceil_up,
               :transparent_proxy, :burst_down, :burst_up, :long_download_max, :long_upload_max

  validates_uniqueness_of :name 
  validates_presence_of :name, :provider_group, :rate_down, :ceil_down, :rate_up, :ceil_up
  validates_length_of :name, :in => 3..128
  validates_numericality_of :rate_down, :ceil_down, :rate_up, :ceil_up, :only_integer => true, :allow_nil => true, :greater_than_or_equal_to => 0
  validates_numericality_of :burst_down, :burst_up, :long_download_max, :long_upload_max, :only_integer => true, :greater_than_or_equal_to => 0

  validate :remaining_rate_down
  validate :remaining_rate_up

  def remaining_rate_down
    if not new_record?
      if rate_down_changed? or provider_group_id_changed?
        remaining_rate_down = if provider_group_id_changed?
          ProviderGroup.find(provider_group_id).remaining_rate_down
        else
          provider_group.gremaining_rate_down + used_rate_down(rate_down_was)
        end
        if used_rate_down > remaining_rate_down
          errors.add(:rate_down, I18n.t('validations.plan.not_enough_down_bandwidth'))
        end
      end
    end
  end

  def remaining_rate_up
    if not new_record?
      if rate_up_changed? or provider_group_id_changed?
        remaining_rate_up = if provider_group_id_changed?
          ProviderGroup.find(provider_group_id).remaining_rate_up
        else
          provider_group.gremaining_rate_up + used_rate_up(rate_up_was)
        end
        if used_rate_up > remaining_rate_up
          errors.add(:rate_up, I18n.t('validations.plan.not_enough_up_bandwidth'))
        end
      end
    end
  end
  def used_rate_down(old_rate_down=nil)
    rd = old_rate_down.nil? ? rate_down : old_rate_down
    multiplier = rd == 0 ? 0.008 : rd
    contracts.count * multiplier
  end
  def used_rate_up(old_rate_up=nil)
    rd = old_rate_up.nil? ? rate_up : old_rate_up
    multiplier = rd == 0 ? 0.008 : rd
    contracts.count * multiplier
  end
  def burst_down_to_bytes
    burst_down * 1024
  end
  def burst_up_to_bytes
    burst_up * 1024
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
