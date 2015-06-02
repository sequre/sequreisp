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

  def view_extensions
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

  def massive_settings_form_extensions(form)
    ""
  end

  def plugins_header_extensions
    ""
  end

  def header_logo_extension
    "background: url(/images/header.png) no-repeat;".html_safe
  end

  def link_footer_extension
  "<a href='http://www.wispro.co'>wispro.co</a>".html_safe
  end

  def heading_name
    "Wispro"
  end

  def massive_settings_form_extensions(form)
    ""
  end

  def background_login_extension
    ""
  end

  def login_logo_extension
    require 'sequreisp_about'
    version = "#{SequreISP::Version::RELEASE}.#{SequreISP::Version::MAJOR}"
    "<div class='logo'></div><h4>#{version}</h4>".html_safe
  end
end
