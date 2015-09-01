require 'syslog'

INFO = 'info'
DEBUG = 'debug'
ERROR = 'error'

@syslog ||=  Syslog.open("Wispro")

def log(string)
  level = case $log_level
          when DEBUG
            Syslog::LOG_DEBUG
          else
            Syslog::LOG_INFO
          end
  @syslog.log(level, string) if can_log?(string)
  puts string if $stdout.tty? and $stdin.tty?
end

def log_rescue(origin, exception)
  @syslog.log(Syslog::LOG_ERR, "#{origin}: #{exception.message}")
  exception.backtrace.each{ |bt| Syslog.log(Syslog::LOG_ERR, "#{origin} #{exception.class} #{bt}") }
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

def can_log?(string)
  case $log_level
  when DEBUG
    true
  when INFO
    string.include?("[DEBUG]") ? false : true
  end
end
