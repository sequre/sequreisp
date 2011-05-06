# http://github.com/javan/whenever
set :output, "log/cron_log.log"

every 5.minutes do
  command "cd /opt/sequreisp/deploy/current/bin/ && ./sequreisp_rrd_feed.sh"
end


