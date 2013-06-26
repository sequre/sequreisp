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

def check_squid
  def squid_pids
    `/usr/bin/pgrep -x squid`.chomp.gsub("\n"," ")
  end
  pid = squid_pids

  #1: is running check
  if pid.blank?
    success = system("/usr/sbin/service squid start")
    Rails.logger.warn "sequreispd: #{Time.now.to_s} squid is not running, forcing start"
  end

  #2: swap.state check
  max_swap_size=500*1024*1024
  swap_file="/var/spool/squid/swap.state"
  swap_size = File.open(swap_file) do |sf| sf.size end
  if swap_size > max_swap_size
    Rails.logger.warn "sequreispd: #{Time.now.to_s} swap.state bigger than max: #{max_swap_size}, current: #{swap_size}, killing"
    max_sleep = 20
    while pid.present? and max_sleep > 0
      system "kill -9 #{pid}"
      sleep 1
      pid = squid_pids
      max_sleep -= 1
    end
    if max_sleep == 0
      Rails.logger.error "sequreispd: #{Time.now.to_s} could not kill squid after 20 tries, aborting"
    else
      Rails.logger.error "sequreispd: #{Time.now.to_s} starting squid"
      old_swap_file="#{swap_file}.old"
      FileUtils.mv swap_file, old_swap_file
      system "/usr/sbin/service squid start"
      FileUtils.rm old_swap_file
    end
  end

  #3: load average check
  max_load_average = Configuration.transparent_proxy_max_load_average
  load_average=`uptime | awk -F "load average:" '{ print $2 }' | cut -d, -f1 | sed 's/ //g'`.chomp.to_f
  if load_average > max_load_average
    Rails.logger.error "sequreispd: #{Time.now.to_s} disabling squid because load average is bigger than max: #{max_load_average}, current: #{load_average}"
    Configuration.first.update_attribute :transparent_proxy, false
    Configuration.first.update_attribute :daemon_reload, true
  end
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
    Configuration.first.update_attribute :backup_restore, "boot"
  when "boot"
    boot
    Configuration.first.update_attribute :last_changes_applied_at, Time.now
    Configuration.first.update_attribute :backup_restore, nil
    if Configuration.backup_reboot
      Configuration.first.update_attribute :backup_reboot, false
      system "/sbin/reboot"
    end
  end
end

#esto va como param a method
tsleep = 1
tsleep_count = 0
while($running) do
  Rails.logger.debug "sequreispd: #{Time.now.to_s} lap tsleep_count: #{tsleep_count}"
  Configuration.do_reload
  tsleep_count += 1

  # check links & squid every 10 seconds
  if tsleep_count%10 == 0
    tsleep_count = 0
    Rails.logger.debug "sequreispd: #{Time.now.to_s} check_physical_links"
    check_physical_links
    Rails.logger.debug "sequreispd: #{Time.now.to_s} check_links"
    check_links
    check_squid if Configuration.transparent_proxy
  end

  Rails.logger.debug "sequreispd: #{Time.now.to_s} DaemonHook"
  # run plugins hooks
  DaemonHook.run({:tsleep => tsleep})

  # checking if we need to apply changes 
  if Configuration.daemon_reload
    Rails.logger.debug "sequreispd: #{Time.now.to_s} boot (apply_changes)"
    Configuration.first.update_attribute :daemon_reload, false
    boot
  end

  if Configuration.backup_restore
    Rails.logger.debug "sequreispd: #{Time.now.to_s} backup_restore"
    backup_restore
  end

  sleep tsleep
end

