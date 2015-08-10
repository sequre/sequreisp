require 'syslog'

def log(string)
  if Rails.env.production?
    Syslog.open if not Syslog.opened?
    Syslog.log(Syslog::LOG_INFO, "[Wispro]#{string}")
    # puts string if $stdout.tty?
  else
    Rails.logger.error("[Wispro]#{string}")
  end
end

def log_rescue(origin, exception)
  if Rails.env.production?
    Syslog.open if not Syslog.opened?
    Syslog.log(Syslog::LOG_ERR, "[Wispro]#{origin}: #{exception.message}")
    exception.backtrace.each{ |bt| Syslog.log(Syslog::LOG_ERR, "[Wispro]#{origin} #{exception.class} #{bt}") }
  else
    Rails.logger.error "[Wispro]#{origin}: #{exception.message}"
    exception.backtrace.each{ |bt| Rails.logger.error("[Wispro]#{origin} #{exception.class} #{bt}") }
  end
end


def log_rescue_file(path, exception)
  File.open(path, 'a+') do |f|
    if exception.instance_of? String
      f.puts DateTime.now
      f.puts "#{DateTime.now} - #{exception}"
    else
      f.puts "#{DateTime.now} - #{exception.message}"
      exception.backtrace.each{ |bt| f.puts "#{exception.class} #{bt}" }
    end
  end
end
