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

module ConfigurationsHelper

  def options_for_mail_relay
    [[t("messages.configuration.own"), "own"], [t("messages.configuration.gmail"), "gmail"]]
  end

  def show_traffic_prio_input(form, key)
    case key
    when "tcp-length"
      form.input :tcp_length
    when "udp-length"
      form.input :udp_length
    else
      ""
    end
  end

end
