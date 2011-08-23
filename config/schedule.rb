# http://github.com/javan/whenever

every 5.minutes do
  command "cd /opt/sequreisp/deploy/current/bin/ && ./sequreisp_rrd_feed.sh", :output => "../log/cron_log.log"
end


