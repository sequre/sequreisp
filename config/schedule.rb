# http://github.com/javan/whenever

every 5.minutes do
  command "cd /opt/sequreisp/deploy/current/bin/ && ./sequreisp_rrd_feed.sh", :output => "../log/cron_log.log"
end

every 1.hour do
  runner "Configuration.apply_changes_automatically!", :output => "log/cron_log.log"
end

Dir.glob(File.join(File.dirname(__FILE__), 'vendor', 'plugins', '**', "config", "schedule.rb")) do |schedule|
    self.send(:eval, File.open(schedule, 'r').read)
end

every 1.day, :at => '3:30 am' do
  runner 'Contract.each{ |contract| contract.create_traffic_for_this_period if contract.current_traffic.nil? }', :output => "log/cron_log.log"
end

every 1.day, :at => '3:30 am' do
  runner 'Contract.all.each{ |contract| contract.create_traffic_for_this_period if contract.current_traffic.nil? }', :output => "log/cron_log.log"
end
