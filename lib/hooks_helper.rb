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

module HooksHelper

  def plugins_menu_links
    []
  end

  def submenu_links
    []
  end

  def form_extensions(form)
    ""
  end

  def search_extensions(form)
    @__search_extensions = {}
  end

  def plugins_table_columns
    []
  end

  def plugins_table_columns_values object
    []
  end

  def show_traffic(contract)
    "#{number_to_human_size(contract.current_traffic.data_count)}"
  end
end
