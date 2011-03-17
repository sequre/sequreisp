#!/usr/bin/env ruby

Contract.all(:conditions => "forward_ports is not null and forward_ports != ''").each do |c| 
  c.forward_ports.split(",").each do |port| 
		in_port,out_port = port.split(":")
    out_port = in_port if out_port.blank? 
    c.provider_group.providers.enabled.each do |p|
      c.forwarded_ports.create!( :provider => p, :public_port => in_port, :private_port => out_port, :tcp => true, :udp => true)
      puts "#{c.id} p #{p.id} public #{in_port} private #{out_port}"
    end
  end
end
