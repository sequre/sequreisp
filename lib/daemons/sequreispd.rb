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

# The limit current_traffic for read is 1 Gbps
@max_current_traffic_count = 1000 / 8 * 1024 * 1024 * 60
conf = Configuration.first

tcounter = Thread.new do
  time_last = (Time.now - 1.minute)
  while true
    if (Time.now - time_last) >= 1.minute
      begin
        hash = {}
        hash_log_iptables = {}
        hash_log_iptables_proxy = {}
        if SequreispConfig::CONFIG["demo"]
          Contract.all.each do |contract|
            hash[contract.ip] = rand(1844674)
          end
        else
          ips = Contract.all.collect(&:ip)
          chain_prefix = conf.iptables_tree_optimization_enabled ? "sq" : "sequreisp"
          # WARN! dobule escape for bracket seems mandatory \\[
          command = "iptables-save -t mangle -c | /bin/grep \"^\\[.*:.*\\] -A #{chain_prefix}.* -[sd] .* -j .*$\""
          IO.popen( command , "r") do |io|
            io.each do |line|
              rule = line.split(" ")
              ip = IP.new(rule[4]).to_s
              if ips.include? ip
                hash[ip] = 0 if hash[ip].nil?
                hash[ip] += rule[0].match('[^\[].*[^\]]').to_s.split(":").last.to_i
                hash_log_iptables[ip] = [] if hash_log_iptables[ip].nil?
                hash_log_iptables[ip] << line
              end
            end
          end
          if conf.transparent_proxy and conf.transparent_proxy_n_to_m
            proxy_bind_ips_hash = Contract.all(:include => :klass).each_with_object({}) do |c,h| h[c.proxy_bind_ip] = c.ip end
            IO.popen("iptables-save -t mangle -c | /bin/grep \"^\\[.*:.*\\] -A OUTPUT -s .* -j .*$\"" , "r") do |io|
              io.each do |line|
                rule = line.split(" ")
                proxy_bind_ip = IP.new(rule[4]).to_s
                ip = proxy_bind_ips_hash[proxy_bind_ip]
                if ips.include? ip
                  hash[ip] = 0 if hash[ip].nil?
                  hash[ip] += rule[0].match('[^\[].*[^\]]').to_s.split(":").last.to_i
                  hash_log_iptables_proxy[ip] = [] if hash_log_iptables_proxy[ip].nil?
                  hash_log_iptables_proxy[ip] << line
                end
              end
            end
          end
        end

        ActiveRecord::Base.transaction do
          #create current traffic for new period
          file = File.join DEPLOY_DIR, "log/data_counting.log"
          contract_count = Contract.count
          File.open(file, "a") do |f|
            Contract.all(:include => :current_traffic).each do |c|
              c.is_connected = false
              traffic_current = c.current_traffic
              if traffic_current.nil?
                traffic_current = c.create_traffic_for_this_period
                #update the data for each traffic
                #c.reload
              end
              if hash[c.ip].present? and hash[c.ip] != 0#no read if contract.state == disabled
                tmp = traffic_current.data_count
                if hash[c.ip] <= @max_current_traffic_count
                  traffic_current.data_count += hash[c.ip]
                  traffic_current.save
                end
                if contract_count <= 300
                  c.reload
                  if (hash[c.ip] >= 7864320) or (c.current_traffic.data_count - tmp >= 7864320) or ((c.current_traffic.data_count - hash[c.ip]) != tmp)
                    hash_log_iptables[c.ip].each do |rule|
                      f.puts("Rule chain: #{rule}")
                    end
                    if conf.transparent_proxy and conf.transparent_proxy_n_to_m
                      hash_log_iptables_proxy[c.ip].each do |rule|
                        f.puts("Rule proxy: #{rule}")
                      end
                    end
                    f.puts "#{Time.now.strftime('%d/%m/%Y %H:%M:%S')}, ip: #{c.ip}(#{c.current_traffic.id}), Data Count: #{tmp},  Data readed: #{hash[c.ip]}, Data Accumulated: #{c.current_traffic.data_count}"
                  end
                end
                c.is_connected = true
              end
              c.save if c.changed?
              DaemonHook.data_counting(:contract => c)
            end
          end
        end
      rescue => e
        Rails.logger.error "ERROR TrafficDaemonThread: #{e.inspect}"
      ensure
        time_last = Time.now
        system "iptables -t mangle -Z" unless SequreispConfig::CONFIG["demo"]
      end
    end
    break unless $running
    sleep 1
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

tcounter.join
