class DaemonLogger

  def initialize(name, level_log)
    @log = Logger.new("#{DEPLOY_DIR}/log/wispro.log", shift_age = 7, shift_size = 1.megabytes)
    @log.level = level_log
    @log.formatter = proc do |severity, datetime, progname, msg|
      datetime_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
      "#{datetime_format} #{Socket.gethostname} #{SOFT_NAME}[#{Process.pid}]: [Priority:#{@priority}][#{severity}][#{name}][#{caller[5].scan(/:in `(.*)'/).flatten.first}] #{msg} \n"
     end
    @log_file_path = "#{DEPLOY_DIR}/log/#{name}"
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
end

class ApplicationLogger

  def initialize
    @log = Logger.new(APPLICATION_LOG, shift_age = 7, shift_size = 1.megabytes)
    @log.formatter = proc do |severity, datetime, progname, msg|
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
