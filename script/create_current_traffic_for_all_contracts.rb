Contract.all.each{ |contract| contract.create_traffic_for_this_period if contract.current_traffic.nil? }
