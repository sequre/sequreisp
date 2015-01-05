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
Signal.trap("TERM") { $running = false }
Signal.trap("INT") { $running = false }
$running = true

# def backup_restore
#   # cheking if we are restoring a backup file
#   # backup_restore:
#   # "respawn_and_boot"
#   #   exits the daemon in order to re-load the just uploaded new code
#   #   sets backup_restore to "boot"
#   # "boot"
#   #   boots the changes
#   #   unsets backup_restore
#   #   if backup_reboot is set then reboots the server
#   #
#   case Configuration.backup_restore
#   when "respawn_and_boot"
#     $running = false
#     Configuration.first.update_attribute :backup_restore, "boot"
#   when "boot"
#     boot
#     Configuration.first.update_attribute :last_changes_applied_at, Time.now
#     Configuration.first.update_attribute :backup_restore, nil
#     if Configuration.backup_reboot
#       Configuration.first.update_attribute :backup_reboot, false
#       system "/sbin/reboot"
#     end
#   end
# end


# def parse_data_count(contracts, hash_count)
#   if SequreispConfig::CONFIG["demo"]
#     contracts.all.each do |contract|
#       hash_count["up"][contract.ip]["data_count"] = rand(1844674)
#       hash_count["down"][contract.ip]["data_count"] = rand(1844674)
#     end
#   else
#     begin
#       # [["bytes", "ip", "up|down", "data_count"], ["bytes", "ip", "up|down", "data_count"]]
#       File.read("|iptables-save -t filter -c").scan(/\[.*:(\d+).*comment \"data-count-(.*)-(.*)-(.*)\"/).each do |line|
#         # line[0] => byte's, line[1] => i1p, line[2] => up | down, line[3] => category, where the category name is the same with  any traffic attribute
#         if line[0] != "0"
#           hash_count[line[2]][line[1]] = {}
#           hash_count[line[2]][line[1]][line[3]] = line[0]
#         end
#       end
#     rescue => e
#       Rails.logger.error "ERROR Daemon: Command iptables-save -t filter -c: #{e.inspect}"
#     end
#   end
# end


# # The limit current_traffic for read is 1 Gbps
# @max_current_traffic_count = 1000 / 8 * 1024 * 1024 * 60
# conf = Configuration.first

# tcounter = Thread.new do
#   time_last = (Time.now - 1.minute)
#   while true
#     if (Time.now - time_last) >= 1.minute
#       hash_count = { "up" => {}, "down" => {} }
#       contracts = Contract.not_disabled(:include => :current_traffic)
#       contract_count = contracts.count
#       parse_data_count(contracts, hash_count)

#       ActiveRecord::Base.transaction do
#         begin
#           File.open(File.join(DEPLOY_DIR, "log/data_counting.log"), "a") do |f|
#             contracts.each do |c|
#               c.is_connected = false

#               Configuration::COUNT_CATEGORIES.each do |category|
#                 data_total = 0
#                 data_total += hash_count["up"][c.ip][category].to_i if hash_count["up"].has_key?(c.ip)
#                 data_total += hash_count["down"][c.ip][category].to_i if hash_count["down"].has_key?(c.ip)

#                 if data_total != 0
#                   c.is_connected = true
#                   traffic_current = c.current_traffic || c.create_traffic_for_this_period
#                   current_traffic_count = traffic_current.data_count
#                   eval("traffic_current.#{category} += data_total") if data_total <= @max_current_traffic_count

#                   #Log data counting
#                   if contract_count <= 300 and Rails.env.production?
#                     if (data_total >= 7864320) or (eval("c.current_traffic.#{category} - current_traffic_count >= 7864320")) or (eval("(c.current_traffic.#{category} - data_total) != current_traffic_count"))
#                       f.puts "#{Time.now.strftime('%d/%m/%Y %H:%M:%S')}, ip: #{c.ip}(#{c.current_traffic.id}), Category: #{Category}, Data Count: #{tmp},  Data readed: #{hash_count[c.ip]}, Data Accumulated: #{c.current_traffic.data_count}"
#                     end
#                   end
#                 end
#               end

#               traffic_current.save if traffic_current.changed?
#               c.save if c.changed?
#               c.reload
#               DaemonHook.data_counting(:contract => c)
#             end
#           end
#         rescue => e
#           Rails.logger.error "ERROR TrafficDaemonThread: #{e.inspect}"
#         ensure
#           time_last = Time.now
#           system "iptables -t filter -Z" if Rails.env.production?
#         end
#       end
#       break unless $running
#       sleep 1
#     end
#   end
# end

# #esto va como param a method
# tsleep = 1
# tsleep_count = 0
# while($running) do
  # Rails.logger.debug "sequreispd: #{Time.now.to_s} lap tsleep_count: #{tsleep_count}"
  # Configuration.do_reload
  # tsleep_count += 1

  # # check links every 10 seconds
  # if tsleep_count%10 == 0
  #   tsleep_count = 0
  #   Rails.logger.debug "sequreispd: #{Time.now.to_s} check_physical_links"
  #   check_physical_links
  #   Rails.logger.debug "sequreispd: #{Time.now.to_s} check_links"
  #   check_links
  # end

  # Rails.logger.debug "sequreispd: #{Time.now.to_s} DaemonHook"
  # # run plugins hooks
  # DaemonHook.run({:tsleep => tsleep})

  # # checking if we need to apply changes
  # if Configuration.daemon_reload
  #   Rails.logger.debug "sequreispd: #{Time.now.to_s} boot (apply_changes)"
  #   Configuration.first.update_attribute :daemon_reload, false
  #   boot
  # end

  # if Configuration.backup_restore
  #   Rails.logger.debug "sequreispd: #{Time.now.to_s} backup_restore"
  #   backup_restore
  # end

  # sleep tsleep
# end
# tcounter.join

require 'sequreisp_constants'
require 'daemon_task'
require "sequreisp_logger"
require 'command_context'

#Thread::abort_on_exception = true

threads = []
begin
  if $running
    DaemonTask.descendants.each do |daemon_task|
      daemon = daemon_task.new
      threads << daemon
      daemon.start
    end
  end
rescue Exception => e
  log_rescue("Sequreispd", e)
ensure
  while($running) do
    threads.each do |thread|
      thread.start if thread.state.nil?
    end
    sleep 1
  end
  threads.map{ |thread| thread.stop }
  threads.map{ |thread| thread.join }
end
