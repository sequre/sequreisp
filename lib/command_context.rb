class CommandContext
  require 'sequreisp_constants'
  require 'sequreisp_logger'
  attr_accessor :commands
  attr_accessor :name
  attr_accessor :message

  def self.run= _run
    @@run = _run
  end

  def initialize name, commands, message=nil
    @@run = true
    @@command_logger = Logger.new File.join Rails.root, "log/command.log"
    @commands = []
    @name = name
    @message = message
    #commands = _commands.to_a if _commands.is_a? String

    commands.each do |command|
      @commands << Command.new(command)
    end
  end

  def exec_commands(f=nil, human=nil)
    commands.each do |c|
      c.exec if @@run
      @@command_logger.info "#{Time.now}, #{name}, #{c.to_log}"
      f.puts c.command if f
    end
    @@command_logger.info "#{Time.now}, #{name}, status: #{status}"
    human.puts "#{Time.now.to_formatted_s(:db)}, #{message}, #{status}" if human
    human.close if human
    status
  end

  def status
    commands.collect(&:status).sum == 0
  end
end
class BootCommandContext < CommandContext
  def self.clear_boot_file
    File.open(BOOT_FILE, 'w') do |f|
      f.truncate 0
      f.chmod 0755
    end
    File.open(File.join(Rails.root, "log/command_human.log"), 'w') {|file| file.truncate(0) }
  end

  def exec_commands
    begin
      f = File.open BOOT_FILE, "a+"
      human = File.open(File.join(Rails.root, "log/command_human.log"), "a+")
      super f, human
    rescue => e
      log_rescue("[CommandContext] Error exec_commands", e)
      # Rails.logger.error "ERROR in lib/sequreisp.rb::exec_commands e=>#{e.inspect}"
    ensure
      f.close if f
    end
  end
end
class Command
  attr_accessor :stdout, :stderr, :pid, :command, :time
  attr_accessor_with_default :status, 0
  def initialize command
    @command = command
  end

  def exec
    start = Time.now
    self.status = Open4::popen4("bash -c '#{command}'") do |pid, stdin, stdout, stderr|
      self.pid = pid
      self.stdout = stdout.read.strip
      self.stderr = stderr.read.strip
    end.exitstatus
    self.time = (Time.now - start).round(2)
  end

  def to_log
    "command: #{command}, status: #{status}, time: #{time}, stdout: #{stdout}, stderr: #{stderr}, pid: #{pid}"
  end
end
