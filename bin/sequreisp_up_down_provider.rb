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

require 'sequreisp'

# saco el environment, no se me ocurre algo más elegante...
if ARGV[0] == "-e"
  ARGV.shift
  ARGV.shift
end

def show_usage
    puts "Invalid arguments, use:"
    puts "    up   provider_interface ip netmask gateway"
    puts "    down provider_interface"
end

action=ARGV[0] 
interface=ARGV[1] 

p = Interface.find_by_name(interface).provider rescue nil #TODO mandar un mail
#puts "#{action}  #{interface}" 
if !p.nil?
  if action == "up"
    ip=ARGV[2]
    netmask=ARGV[3]
    gateway=ARGV[4]
    #puts "up #{ip} #{netmask} #{gateway}"
    if !ip.blank? and !netmask.blank? and !gateway.blank? 
      p.ip=ip
      p.netmask=netmask
      p.gateway=gateway
      if p.save
        do_provider_up p
      else
        show_usage 
      end
    else
      show_usage
    end
  elsif action == "down"
    puts "down"
    do_provider_down p
  else
    show_usage
  end
else
  show_usage
end
