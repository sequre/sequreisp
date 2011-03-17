#!/usr/bin/env ruby
require 'csv'
count = 0
failed = []
CSV.open("./demoplanes4.csv", "r") do |row|
  count += 1
  next if count == 1
  #puts "#{row.inspect}"
  #puts "#{row[0]}"
  name = "#{row[1].to_s.strip} #{row[0].to_s.strip}"
  phone = "#{row[5].to_s.strip}"
  phone_mobile = "#{row[6].to_s.strip}"
  piso = row[3].blank? ? "" : " Piso #{row[3].to_s.strip}"
  dpto = row[4].blank? ? "" : " Dpto. #{row[4].to_s.strip}"
  address = "#{row[2].to_s.strip}#{piso}#{dpto}" 
  ip = "#{row[7].to_s.strip}"
  plan = Plan.find_by_name(row[8].to_s.strip)
  puts ":name #{name} :phone #{phone} :phone_mobile #{phone_mobile} :address #{address} :ip #{ip} :plan #{plan.name rescue "fallo #{row[8].to_s.strip}"}"
  begin 
    c = Client.find_by_name_and_address(name, address)
    c = Client.create! :name => name, :phone => phone, :phone_mobile => phone_mobile, :address => address, :send_notifications => false unless c
    co = Contract.create! :ip => ip, :plan => plan, :ceil_dfl_percent => 70, :client => c
  rescue Exception => e
    puts "Exception: #{e.message}"
    message = ""
    if c.nil?
      message = "fallo cliente #{e.message}"
    else
      message = "fallo contrato #{e.message}"
    end
    failed << "fila: #{row.join(", ")}"
    failed << "error: #{message}"
    failed << ""
  end
end
File.open("./failed.csv", "w") do |f|
  failed.each do |r|
    f.puts r
  end
end
