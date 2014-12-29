# Esto lo tengo que poner en el demonio principal para que me capture las execption que larguen los threads
#
require 'syslog'
require 'sequreisp_constants'
Syslog.open
Thread::abort_on_exception = true

def start_all
  foo = []
  DaemonTask.descendants.each do |a|
    bar = a.new
    foo << bar
    bar.start
  end
  foo
end


class DaemonTask

  def initialize
    @thread_daemon = nil
    @name = self.class.to_s.underscore.gsub("_"," ").capitalize
    # @next_exec ||= self::TIME.has_key?(:begin_in) ? Time.parse(self::TIME[:begin_in], Time.new) : Time.new
    @next_exec ||= @time_for_exec.has_key?(:begin_in) ? Time.parse(@time_for_exec[:begin_in], Time.new) : Time.new
  end

  def stop
    if @thread_daemon.exit
      Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] stop thread #{name}")
      Syslog.close
    end
  end

  def set_next_exec
    @next_exec += @time_for_exec[:frecuency]
  end

  #Como esta el thread, en ejecucion, caido, blabla
  def state?
    @thread_daemon.status
  end

  def name
    @name
  end

  def thread
    @thread_daemon
  end

  # give all subclasses
  def self.descendants
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end

end

class DaemonApplyChange < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 10.seconds }
    super
  end

  def start
    @thread_daemon = Thread.new do
      Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] Start Thread #{name}")
      Syslog.close
      Thread.current["name"] = @name
      while true
        if Time.now >= @next_exec #and Configuration.daemon_reload
          # Configuration.first.update_attribute :daemon_reload, false
          # boot
          Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] exec Thread #{name}")
          Syslog.close
          set_next_exec
        else
          Thread.pass
        end
      end
    end
  end

end

class DaemonApplyChangeAutomatically < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 1.hour }
    super
  end

  def start
    @thread_daemon = Thread.new do
      Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] Start Thread #{name}")
      Syslog.close
      Thread.current["name"] = @name
      while true
        if Time.now >= @next_exec
          # Configuration.apply_changes_automatically!
          Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] exec Thread #{name}")
          Syslog.close
          set_next_exec
        else
          Thread.pass
        end
      end
    end
  end

end

class DaemonCheckLink < DaemonTask
#  TIME = { :begin_in => "4:15 am", :frecuency => 1.day }
  # TIME = { :frecuency => 10.seconds }

  def initialize
    @time_for_exec = { :frecuency => 10.seconds }
    super
  end

  def start
    @thread_daemon = Thread.new do
      Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] Start Thread #{name}")
      Syslog.close
      Thread.current["name"] = @name
      while true
        if Time.now >= @next_exec
          Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] exec thread #{name}")
          Syslog.close
          set_next_exec
          # check_physical_links
          # check_links
        else
          Thread.pass
        end
      end
    end
  end

end

class DaemonBackupRestore < DaemonTask
#  TIME = { :begin_in => "4:15 am", :frecuency => 1.day }
  # TIME = { :frecuency => 10.seconds }

  def initialize
    @time_for_exec = { :frecuency => 10.seconds }
    super
  end

  def start
    @thread_daemon = Thread.new do
      Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] Start Thread #{name}")
      Syslog.close
      Thread.current["name"] = @name
      while true
        if Time.now >= @next_exec #and Configuration.backup_restore
          Syslog.log(Syslog::LOG_INFO, "[SequreISP][Daemon] exec thread #{name}")
          Syslog.close
          set_next_exec
          # backup_restore
        else
          Thread.pass
        end
      end
    end
  end

  def backup_restore
    case Configuration.backup_restore
    when "respawn_and_boot"
      $running = false
      Configuration.first.update_attribute :backup_restore, "boot"
    when "boot"
      boot
      Configuration.first.update_attribute :last_changes_applied_at, Time.now
      Configuration.first.update_attribute :backup_restore, nil
      if Configuration.backup_reboot
        Configuration.first.update_attribute :backup_reboot, false
        system "/sbin/reboot"
      end
    end
  end

end
