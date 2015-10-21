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

puts
puts "#{F_GREEN}Version:#{CLOSE_COLOR} " + Configuration.app_version
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

daemons = Dashboard::Daemon.load_all
services = Dashboard::Service.load_all

daemons_row_size = daemons.collect{|d| d.name.length }.max
services_row_size = services.collect{|s| s.name.length }.max

puts "#{F_YELLOW}#{'Daemons'.ljust(daemons_row_size)}#{CLOSE_COLOR}" + " " * 8 + "  #{F_YELLOW}Services#{CLOSE_COLOR}"
[daemons.count, services.count].max.times do |i|
  if daemons[i]
    print "  #{daemons[i].name.ljust(daemons_row_size)} #{daemons[i].status ? "#{F_GREEN}[OK]   " : "#{F_RED}[ERROR]"}#{CLOSE_COLOR}"
  else
    print " " * (daemons_row_size + 8)
  end

  if services[i]
    puts "  #{services[i].name.ljust(services_row_size)} CPU: #{services[i].cpu_p.to_s.ljust(5)} MEM: #{services[i].mem.round(2).to_s.ljust(7)} #{services[i].up ? "#{F_GREEN}[UP]" : "#{F_RED}[DOWN]"}#{CLOSE_COLOR}"
  else
    puts
  end
end

puts
puts "#{F_YELLOW}CPU#{CLOSE_COLOR}"
load_average = Dashboard::LoadAverage.new
cpus = Dashboard::Cpu.new.stats.sort_by_key.collect{|cpu, values| {cpu => "  #{cpu.upcase.ljust(7)}: [#{F_GREEN}" + ("|" * (values[:total].to_i/2) + " " * ((100 - values[:total].to_i)/2)).rjust(50,"|") + "#{CLOSE_COLOR}#{values[:total].to_s.rjust(6)}%]"} }
cpu_all = cpus.pop
cpus.map(&:values).each{|info| puts info.first }
print cpu_all.values.first
puts "  #{F_YELLOW}Load Average:#{CLOSE_COLOR} Now = #{load_average.now}, 5min = #{load_average.min5}, 15min = #{load_average.min15}"

puts
puts "#{F_YELLOW}Disks#{CLOSE_COLOR}"
Dashboard::Disk.load_all.each do |disk|
  disk_name = disk.device.split('/').last.split('-').last
  total_g = (disk.total/1.megabytes.to_f).round(1)
  puts "  #{F_MAGENTA}#{disk_name}: [" + ("*" * (disk.used_p/2) + "." * (disk.free_p/2)).rjust(50,"*") + "] #{disk.used_p}% (#{total_g*disk.used_p/100}GB/#{total_g}GB) on #{disk.mount_point}#{CLOSE_COLOR}"
end