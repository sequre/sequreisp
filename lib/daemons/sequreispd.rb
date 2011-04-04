#!/usr/bin/env ruby

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


# You might want to change this
#ENV["RAILS_ENV"] ||= "production" ROD
ENV["RAILS_ENV"] ||= "production" 

require File.dirname(__FILE__) + "/../../config/environment"
require 'sequreisp'

# sino no salen los logs en production
RAILS_DEFAULT_LOGGER.auto_flushing = 1

create_dirs_if_not_present if Rails.env == 'development'



$running = true
Signal.trap("TERM") do 
  $running = false
end
#esto va como param a method
tsleep = 1
tsleep_count = 0
while($running) do
  tsleep_count += 1
  if tsleep_count%10 == 0
    #Rails.logger.debug "sequreispd: check links"
    tsleep_count = 0
    check_physical_links
    check_links
  end
  DaemonHook.run({:tsleep => tsleep})

  #Rails.logger.debug "sequreispd: chequeando daemon_reload"
  Configuration.do_reload
  if Configuration.daemon_reload
    #Rails.logger.debug "sequreispd: reloading..."
    boot
    Configuration.daemon_reload = false
    Configuration.record_timestamps = false
    Configuration.save
    Configuration.record_timestamps = true
  end

  system "#{ARP_FILE}"
  sleep tsleep

end

