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
ENV["RAILS_ENV"] ||= "production"

# load rails
require File.dirname(__FILE__) + "/../../config/environment"
# load sequreisp
require 'sequreisp'
create_dirs_if_not_present if Rails.env == 'development'

# hack arround to make daemon avaible to log to production
RAILS_DEFAULT_LOGGER.auto_flushing = 1

# our running var
$running = true
Signal.trap("TERM") do
  $running = false
end

def backup_restore
  # cheking if we are restoring a backup file
  # backup_restore:
  # "respawn_and_boot"
  #   exits the daemon in order to re-load the just uploaded new code
  #   sets backup_restore to "boot"
  # "boot"
  #   boots the changes
  #   unsets backup_restore
  #   if backup_reboot is set then reboots the server
  #
  case Configuration.backup_restore
  when "respawn_and_boot"
    $running = false
    Configuration.backup_restore = "boot"
    Configuration.save
  when "boot"
    boot
    Configuration.last_changes_applied_at = Time.now
    Configuration.backup_restore = nil
    Configuration.save
    if Configuration.backup_reboot
      Configuration.backup_reboot = false
      Configuration.save
      system "/sbin/reboot"
    end
  end
end

#esto va como param a method
tsleep = 1
tsleep_count = 0
while($running) do
  Configuration.do_reload
  tsleep_count += 1

  # check links
  if tsleep_count%10 == 0
    #Rails.logger.debug "sequreispd: check links"
    tsleep_count = 0
    check_physical_links
    check_links
  end

  # run plugins hooks
  DaemonHook.run({:tsleep => tsleep})

  # checking if we need to apply changes 
  if Configuration.daemon_reload
    #Rails.logger.debug "sequreispd: reloading..."
    boot
    Configuration.daemon_reload = false
    Configuration.save
  end

  backup_restore if Configuration.backup_restore

  # I'm not shure if this is no longer needed
  # at first it arp fixed entries seems to expire after a while
  system "#{ARP_FILE}"

  sleep tsleep
end

