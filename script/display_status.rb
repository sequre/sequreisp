# FOREGROUND COLOR
F_BLACK="\033[30m"
F_RED="\033[31m"
F_GREEN="\033[32m"
F_YELLOW="\033[33m"
F_BLUE="\033[34m"
F_MAGENTA="\033[35m"
F_CYAN="\033[36m"
F_WHITE="\033[37m"

# BACKGROUND COLOR
B_BLACK = "\033[40m"
B_RED = "\033[41m"
B_GREEN = "\033[42m"
B_YELLOW = "\033[43m"
B_BLUE = "\033[44m"
B_MAGENTA = "\033[45m"
B_CYAN = "\033[46m"
B_WHITE = "\033[47m"
CLOSE_COLOR="\033[0m"

def show_human_down_up down, up
  _suffix = suffix [ down, up ].max
  "#{to_suffix(down, _suffix)} / #{to_suffix(up, _suffix)} #{_suffix}"
end

def suffix number
  number < 1024 ? "kbps" : "mbps"
end

def to_suffix number, suffix
  if suffix == "kbps"
    number
  else
    "%g" % (number / 1024.0).round(2)
  end
end

if Configuration.first.in_safe_mode?
  puts "             #{F_RED}##########################################{CLOSE_COLOR}"
  puts
  puts "                         #{F_RED}YOU ARE IN SAFE MODE#{CLOSE_COLOR}         "
  puts
  puts "             #{F_RED}##########################################{CLOSE_COLOR}"
end

puts
puts "#{F_GREEN}Wispro Version:#{CLOSE_COLOR} " + Configuration.app_version
puts "#{F_GREEN}Kernel Version:#{CLOSE_COLOR} " + Configuration.kernel_version
puts

puts "#{F_YELLOW}Interfaces#{CLOSE_COLOR}"
max_interface_name_size = Interface.all.collect{|i| i.name.length }.max
Interface.only_wan.each do |iface|
  puts "  #{F_GREEN}#{iface.name.ljust(max_interface_name_size)}#{CLOSE_COLOR}#{F_YELLOW} WAN#{CLOSE_COLOR} [" + (iface.status == 'up' ? "#{F_GREEN}UP" : "#{F_RED}DOWN") + "#{CLOSE_COLOR}]" +
       (iface.provider.present? ? " #{iface.provider.name} (#{iface.provider.kind}) #{iface.provider.ip} #{iface.provider.rate_down}/#{iface.provider.rate_up}" + " (#{F_MAGENTA}#{iface.provider.provider_group.name}#{CLOSE_COLOR})" + " [" + (iface.provider.status == 'online' ? "#{F_GREEN}ONLINE" : "#{F_RED}OFFLINE") + "#{CLOSE_COLOR}] " : '')
end

Interface.only_lan.each do |iface|
  puts "  #{F_GREEN}#{iface.name.ljust(max_interface_name_size)}#{CLOSE_COLOR}#{F_YELLOW} LAN#{CLOSE_COLOR} [" + (iface.status == 'up' ? "#{F_GREEN}UP" : "#{F_RED}DOWN") + "#{CLOSE_COLOR}] " + iface.addresses.collect(&:ip).join(',')
end

puts

puts "#{F_YELLOW}Contracts#{CLOSE_COLOR}"
print "  Online (#{F_GREEN + Contract.how_many_connected.count.to_s + CLOSE_COLOR}/#{Contract.count})"
print "     #{F_GREEN}Enabled (#{Contract.enabled.count})#{CLOSE_COLOR} | #{F_YELLOW}Alerted (#{Contract.all(:conditions => "state = 'alerted'").count})#{CLOSE_COLOR} | #{F_RED}Disabled (#{Contract.all(:conditions => "state = 'disabled'").count})#{CLOSE_COLOR}"

notified_contracts = NotifiedContract.not_seen.applicables.all(:conditions => "notifications.notification_type = 'redirection' and ADDDATE(notifications.created_at, notifications.ends_in) >= NOW()", :group => "contract_id").count
notified_clients = NotifiedClient.unconfirmed.applicables.all(:group => "client_id").count
puts "     #{F_CYAN}Notified (#{notified_contracts + notified_clients})#{CLOSE_COLOR}"
puts

puts "#{F_YELLOW}Plans (only with contracts)#{CLOSE_COLOR}"
plans = []
ljusts = [0,0,0,0,0]
Plan.all.each do |p|
  plan = []
  contract_counts = p.contracts.count
  if contract_counts > 0
    name = p.name
    ceil = show_human_down_up(p.ceil_down, p.ceil_up)
    cir = show_human_down_up(p.cir_total_down, p.cir_total_up)
    strategy = p.cir_strategy
    pgroup = p.provider_group.name rescue 'Undefined'
    ljusts[0] = name.length     if name.length     > ljusts[0]
    ljusts[1] = ceil.length     if ceil.length     > ljusts[1]
    ljusts[2] = cir.length      if cir.length      > ljusts[2]
    ljusts[3] = strategy.length if strategy.length > ljusts[3]
    ljusts[4] = pgroup.length   if pgroup.length   > ljusts[4]
    plan = [name, ceil, cir, strategy, pgroup, contract_counts]
  end
  plans << plan unless plan.empty?
end

plans.each { |p| puts "  #{p[0].ljust(ljusts[0])} #{F_GREEN}#{p[1].ljust(ljusts[1])}#{CLOSE_COLOR} #{F_YELLOW}#{p[2].ljust(ljusts[2])}#{CLOSE_COLOR} #{F_CYAN}(#{p[3].ljust(ljusts[3])})#{CLOSE_COLOR} #{F_MAGENTA}(#{p[4].ljust(ljusts[4])})#{CLOSE_COLOR} #{F_GREEN}(#{p[5]})#{CLOSE_COLOR}" }
puts

daemons = Dashboard::Daemon.load_all
services = MoolService.all(Dashboard::SERVICES)

daemons_row_size = daemons.collect{|d| d.name.length }.max
services_row_size = services.keys.collect(&:length).max

puts "#{F_YELLOW}#{'Daemons'.ljust(daemons_row_size)}#{CLOSE_COLOR}" + " " * 8 + "  #{F_YELLOW}Services#{CLOSE_COLOR}"
[daemons.count, services.count].max.times do |i|
  if daemons[i]
    print "  #{daemons[i].name.ljust(daemons_row_size)} #{daemons[i].status ? "#{F_GREEN}[OK]   " : "#{F_RED}[ERROR]"}#{CLOSE_COLOR}"
  else
    print " " * (daemons_row_size + 8)
  end

  if s = services.shift
    service_name = s.first
    service = s.last
    puts "  #{service_name.ljust(services_row_size)} CPU: #{((service.messure.any? ? service.messure.sum{|m| m[:cpu_percentage].to_f } : 0.0).to_s + '%').ljust(5)} MEM: #{((service.messure.any? ? (service.messure.sum{|m| m[:mem_average].to_f}) : 0).to_s + '%').ljust(7)} #{service.messure.any? ? "#{F_GREEN}[UP]" : "#{F_RED}[DOWN]"}#{CLOSE_COLOR}"
  else
    puts
  end
end

puts

puts "#{F_YELLOW}Processes#{CLOSE_COLOR}"
processes = `/bin/ps x | grep [s]equreispd`.split("\n").collect{|l| "#{l.split.last} (#{l.split.first})" }
monitor_process = processes.delete(processes.select{|p| p.include?('sequreispd.rb_monitor')}.first)
main_process = processes.delete(processes.select{|p| p.include?('sequreispd.rb')}.first)
puts "  #{F_MAGENTA}#{monitor_process}#{CLOSE_COLOR}" if monitor_process
puts "  #{F_MAGENTA}#{main_process}#{CLOSE_COLOR}" if main_process
indent = (main_process ? "    " : "  ")
processes.each{|p| puts indent + F_CYAN + p + CLOSE_COLOR }

puts

puts "#{F_YELLOW}APPLICATION LOGGER:#{CLOSE_COLOR} " + (File.zero?("#{DEPLOY_DIR}/log/application.log") ? "#{F_GREEN}[NO ERROR]#{CLOSE_COLOR}" : ("#{F_RED}[PLEASE CHECK IT]#{CLOSE_COLOR}" + " #{F_CYAN}#{DEPLOY_DIR}/log/application.log#{CLOSE_COLOR}"))
puts

daemon_end_execution_time_path = DEPLOY_DIR+"/log/execution_time_daemon"
if File.exist?(daemon_end_execution_time_path)
  puts("#{F_YELLOW}The Daemon have been restarted for last time at:#{CLOSE_COLOR} #{F_RED}#{IO.readlines(daemon_end_execution_time_path).last.chomp}#{CLOSE_COLOR}")
  puts("#{F_YELLOW}For more information check:#{CLOSE_COLOR} #{F_CYAN}#{daemon_end_execution_time_path}#{CLOSE_COLOR}")
  puts
end

puts "#{F_YELLOW}CPU#{CLOSE_COLOR}"
load_average = MoolLoadAverage.new
cpus = MoolCpu.all.sort_by(&:cpu_name).collect{|cpu| {cpu => "  #{cpu.cpu_name.upcase.ljust(7)}: [#{F_GREEN}" + ("|" * (cpu.total/2) + " " * ((100 - cpu.total)/2)).rjust(50,"|") + "#{CLOSE_COLOR}#{cpu.total.to_s.rjust(6)}%]"} }
cpu_all = cpus.pop
cpus.map(&:values).each{|info| puts info.first }
print cpu_all.values.first
puts "  #{F_YELLOW}Load Average:#{CLOSE_COLOR} Now = #{load_average.current_loadavg}, 5min = #{load_average.last_5min_loadavg}, 15min = #{load_average.last_15min_loadavg}"

puts
puts "#{F_YELLOW}Disks#{CLOSE_COLOR}"
MoolDisk.all_usable.each do |disk|
  disk.to_gb
  puts "  #{F_MAGENTA}#{(disk.logical_name + ':').ljust(6)} [" + ("*" * (disk.used_percent/2).round(2) + "." * (disk.free_percent/2).round(2)).rjust(50,"*") + "] #{disk.used_percent.round(2)}% (#{disk.block_used.round(2)}GB/#{disk.total_block.round(2)}GB) on #{disk.mounting_point}#{CLOSE_COLOR}"
end
