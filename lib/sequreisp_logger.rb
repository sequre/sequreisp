require 'syslog'

def log(string)
  Syslog.open if not Syslog.opened?
  Syslog.log(Syslog::LOG_INFO, string)
  # puts string if $stdout.tty?
end

def log_rescue(origin, exception)
  Syslog.log(Syslog::LOG_ERR, "[SequreISP][#{origin}] ERROR Thread #{name}: #{exception.message}")
  exception.backtrace.each{ |bt| Syslog.log(Syslog::LOG_ERR, "[SequreISP][#{origin}] Error Thread #{name} #{exception.class} #{bt}") }
end

def log_rescue_file(path, exception)
  File.open(path, 'w') do |f|
    f.puts exception.message
    exception.backtrace.each{ |bt| f.puts "#{exception.class} #{bt}" }
  end
end
