Interface.all.each do |i|
  i.mac_address = `ip li show dev #{i.name} 2>/dev/null`.match(/link\/ether ([0-9a-fA-F:]+)/)[1] rescue nil
  i.send(:update_without_callbacks)
end
