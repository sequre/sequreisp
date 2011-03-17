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

module GraphsHelper
  def instant_rate_path
    case @graph.element.class.to_s 
    when "Contract"
      instant_rate_contract_path(@graph.element)
    when "Provider" 
      instant_rate_interface_path(@graph.element.interface)
    when "ProviderGroup"
      instant_rate_provider_group_path(@graph.element)
    when "Interface"
      instant_rate_interface_path(@graph.element)
    end
  end
end
