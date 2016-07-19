class DaemonLogger

  def initialize(name, level_log, priority)
    FileUtils.rm("#{DEPLOY_DIR}/log/#{name}") if File.exist?("#{DEPLOY_DIR}/log/#{name}")
    @log = Logger.new("#{DEPLOY_DIR}/log/#{name}.log", shift_age = 7, shift_size = 10.megabytes)
    @log.level = level_log
    @log.formatter = proc do |severity, datetime, progname, msg|
      datetime_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
      "#{datetime_format} #{Socket.gethostname} #{SOFT_NAME}[#{Process.pid}]: [Priority:#{priority}][#{severity}][#{name}][#{caller[5].scan(/:in `(.*)'/).flatten.first}] #{msg} \n"
    end
    @log_file_path = "#{DEPLOY_DIR}/log/#{name}.error"
    remove_log_file
    FileUtils.touch @log_file_path
  end

  def info message
    @log.info message
  end

  def debug message
    @log.debug message
  end

  def error exception
    @log.error("[MESSAGE] #{exception.message}")
    exception.backtrace.each{ |bt| @log.error("[BRACKTRACE] #{bt}") }
    error_to_file(exception)
  end

  def error_to_file exception
    File.open(@log_file_path, 'a+') do |f|
      date_now = DateTime.now
      if exception.instance_of? String
        f.puts "#{date_now} - #{exception}"
      else
        f.puts "#{date_now} - #{exception.message}"
        exception.backtrace.each{ |bt| f.puts "#{date_now} #{exception.class} #{bt}" }
      end
    end
  end

  def remove_log_file
    FileUtils.rm(@log_file_path) if File.exist?(@log_file_path)
  end
end

class ApplicationLogger

  def initialize
    @log = Logger.new(APPLICATION_LOG, shift_age = 7, shift_size = 10.megabytes)
    @log.formatter = proc do |severity, datetime, progname, msg|
      FileUtils.chown('sequreisp', 'sequreisp', APPLICATION_LOG) if Rails.env.production?
      datetime_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
      model, method = caller[5].scan(/\/models\/(.*)\.rb.*:in `(.*)'/).map{|i| [i.first.camelize, i.last] }.flatten
      "#{datetime_format} #{Socket.gethostname} #{SOFT_NAME}[#{Process.pid}]: [#{severity}][Model][#{model}][Method][#{method}] #{msg} \n"
    end
  end

  def info message
    @log.info message
  end

  def debug message
    @log.debug message
  end

  def error exception
    @log.error("[MESSAGE] #{exception.message}")
    exception.backtrace.each{ |bt| @log.error("[BRACKTRACE] #{bt}") }
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


# require 'syslog'

# def log(string)
#   if Rails.env.production?
#     Syslog.open if not Syslog.opened?
#     Syslog.log(Syslog::LOG_INFO, "[Wispro]#{string}")
#     # puts string if $stdout.tty?
#   else
#     Rails.logger.error("[Wispro]#{string}")
#   end
# end

# def log_rescue(origin, exception)
#   if Rails.env.production?
#     Syslog.open if not Syslog.opened?
#     Syslog.log(Syslog::LOG_ERR, "[Wispro]#{origin}: #{exception.message}")
#     exception.backtrace.each{ |bt| Syslog.log(Syslog::LOG_ERR, "[Wispro]#{origin} #{exception.class} #{bt}") }
#   else
#     Rails.logger.error "[Wispro]#{origin}: #{exception.message}"
#     exception.backtrace.each{ |bt| Rails.logger.error("[Wispro]#{origin} #{exception.class} #{bt}") }
#   end
# end
