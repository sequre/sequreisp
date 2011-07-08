#!/usr/bin/env ruby
#

IPTABLES_FILE="/tmp/sequreisp/scripts/iptables"
OUTPUT_FILE="/tmp/iptables.sh"
table=nil
File.open(OUTPUT_FILE, "w") do |f|
  File.open(IPTABLES_FILE, "r").each do |line|
    if line.match /^\*(.*)$/
      table=$1
      f.puts "iptables -t #{table} -F"
      f.puts "iptables -t #{table} -X"
    elsif line.match /^-/
      f.puts "iptables -t #{table} #{line}"
    elsif line.match /^:([^ ]+) .*$/
      f.puts "iptables -t #{table} -N #{$1}"
    end
  end
  f.chmod 0755
end
