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

module AuditsHelper

  def expand_changes(changes,type)
    html = ""
    html << "<ul>"
    changes.each do |key,value|
      if value.class == Array
        val = "<span style=\"text-decoration:line-through;\"> #{value[0]}</span> -> #{value[1]}"
      else
        val = value
      end
      html << "<li><b>#{type.constantize.send :human_attribute_name, key}:</b> #{val}</li>"
    end
    html << "</ul>"
    html
  end

  def link_to_auditable(audit)
    a = nil
    case audit.auditable_type
      when "ForwardedPort"
        a = audit.auditable.contract rescue nil
      when "Address"
        a = audit.auditable.addressable rescue nil
      else
        a = audit.auditable
    end
    if a.nil?
      'N/A'
    else
      link_to(h(a.auditable_name), a)
    end
  end
end
