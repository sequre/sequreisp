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
  acts_as_audited
  belongs_to :provider_group
  has_many :contracts, :dependent => :destroy, :include => :klass
  validates_uniqueness_of :name 
  validates_presence_of :name, :provider_group, :rate_down, :ceil_down, :rate_up, :ceil_up
  validates_length_of :name, :in => 3..128
  validates_numericality_of :rate_down, :ceil_down, :rate_up, :ceil_up, :only_integer => true, :allow_nil => true, :greater_than_or_equal_to => 0
  validates_numericality_of :burst_down, :burst_up, :only_integer => true, :greater_than_or_equal_to => 0

  def burst_to_bytes(burst)
    burst * 1024
  end
  def burst_down_to_bytes
    burst_to_bytes burst_down
  end
  def burst_up_to_bytes
    burst_to_bytes burst_up
  end

end
