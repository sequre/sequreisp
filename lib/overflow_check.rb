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

module OverflowCheck
  #INT_OVERFLOW=4294967295
  INT_OVERFLOW=18446744073709551615
  def check_integer_overflow
#    self.consumption_down_prio -= INT_OVERFLOW if not self.consumption_down_prio.nil? and self.consumption_down_prio > INT_OVERFLOW
#    self.consumption_down_dfl -= INT_OVERFLOW if not self.consumption_down_dfl.nil? and self.consumption_down_dfl > INT_OVERFLOW
#    self.consumption_up_prio -= INT_OVERFLOW if not self.consumption_up_prio.nil? and self.consumption_up_prio > INT_OVERFLOW
#    self.consumption_up_dfl -= INT_OVERFLOW if not self.consumption_up_dfl.nil? and self.consumption_up_dfl > INT_OVERFLOW
    self.consumption_down_prio -= INT_OVERFLOW if self.consumption_down_prio > INT_OVERFLOW
    self.consumption_down_dfl -= INT_OVERFLOW if self.consumption_down_dfl > INT_OVERFLOW
    self.consumption_up_prio -= INT_OVERFLOW if self.consumption_up_prio > INT_OVERFLOW
    self.consumption_up_dfl -= INT_OVERFLOW if self.consumption_up_dfl > INT_OVERFLOW
  end
end
