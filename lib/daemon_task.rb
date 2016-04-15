if Rails.env.development?
  require 'sequreisp_logger'
  require 'sequreisp_constants'
  #Thread::abort_on_exception = true
  require 'benchmark'

  def start_all
    daemons = []
    DaemonTask.descendants.each do |daemon|
      thread = daemon.new
      daemons << thread
      thread.start
    end
    daemons
  end
end

$mutex = Mutex.new
@@update_execution = Mutex.new
$resource = ConditionVariable.new

class DaemonTask

  def initialize
    @thread_daemon = nil
    @name = self.class.to_s
    @conf_daemon ||= $daemon_configuration[@name.underscore]
    @exec_as_process = @conf_daemon["exec_as_process"].present?
    @time_for_exec[:frecuency] = eval(@conf_daemon["frecuency"])
    @priority = @conf_daemon.has_key?("priority") ? @conf_daemon["priority"].to_i : -5
    @daemon_logger = DaemonLogger.new(@name.underscore.downcase, @conf_daemon["level_log"].to_i, @priority)
    init_next_execution_time
    @daemon_logger.info("[START][PRIORITY:#{@priority}][EXEC_AT] #{@next_exec}")
  end

  def exec_command(command)
    result_command = {}
    result_command[:status] = Open4::popen4("bash -c '#{command}'") do |pid, stdin, stdout, stderr|
      result_command[:pid] = pid
      result_command[:stdout] = stdout.read.strip
      result_command[:stderr] = stderr.read.strip
    end.exitstatus
    @daemon_logger.debug("[EXEC_COMMAND] command: #{command}, pid: #{result_command[:pid]}, stdout: #{result_command[:stdout]}, stdout: #{result_command[:stderr]}")
    result_command
  end

  def stop; @exec_as_process ? stop_process : stop_thread; end

  def stop_thread
    begin
      @thread_daemon.exit
      @daemon_logger.info("[STOP]")
    rescue Exception => e
      @daemon_logger.error(e)
    end
  end


  def stop_process
    @daemon_logger.info("[SEND_SIGNAL_TERM] #{@name} (#{pid})")
    Process.kill("TERM", pid)
    status = Process.wait2(pid).last
    @daemon_logger.info("[WAITH_FOR_DAEMON_PROCESS] NAME: #{name} PID: #{status.pid} EXITSTATUS: #{status.exitstatus.inspect}")
  end

  def init_next_execution_time
    configuration = Configuration.first
    @next_exec = @time_for_exec.has_key?(:begin_in) ? Time.parse(@time_for_exec[:begin_in], Time.new) : Time.now
    @next_exec += @time_for_exec[:frecuency] if Time.now > @next_exec

    if configuration.respond_to?("#{@name.underscore}_next_exec_time")
      if configuration.send("#{@name.underscore}_next_exec_time").nil?
        @@update_execution.synchronize {
          configuration.update_attribute("#{@name.underscore}_next_exec_time", @next_exec)
          @daemon_logger.debug("Generate next exec time for: #{configuration.send("#{@name.underscore}_next_exec_time")}")
        }
      else
        @next_exec = configuration.send("#{@name.underscore}_next_exec_time")
        @daemon_logger.debug("Get next exec time for: #{configuration.send("#{@name.underscore}_next_exec_time")}")
      end
    end
  end

  def set_next_execution_time
    configuration = Configuration.first

    while @next_exec <= Time.now
      @next_exec += @time_for_exec[:frecuency]
    end

    if configuration.respond_to?("#{@name.underscore}_next_exec_time")
      @@update_execution.synchronize {
        configuration.update_attribute("#{@name.underscore}_next_exec_time", @next_exec)
        @daemon_logger.debug("[Daemon][#{name}][UPDATE] Next exec time for: #{configuration.send("#{@name.underscore}_next_exec_time")}")
      }
    end
  end

  def start; @exec_as_process ? start_as_process : start_as_thread; end

  def start_as_thread
    @thread_daemon = Thread.new do
      Thread.current["name"] = @name
      Thread.current.priority = @priority
      loop do
        begin
         if Time.now >= @next_exec
           report = nil
           Benchmark.bm do |x|
              report = x.report {
                Configuration.do_reload
                set_next_execution_time
                applying_changes? if @wait_for_apply_changes and Rails.env.production?
                @proc.call #if Rails.env.production?
                @daemon_logger.debug("[NEXT_EXEC_TIME] #{@next_exec}")
              }
            end
           @daemon_logger.info("[REPORT_DAEMON_EXEC] USER_TIME => #{report.utime}, TOTAL_TIME => #{report.total}, REAL_TIME => #{report.real}")
          end
        rescue Exception => e
          @daemon_logger.error(e)
        end
        to_sleep
      end
    end
  end

  def start_as_process
    process_name = "sequreispd_#{@name.underscore}"
    pid = `pidof #{process_name}`.chomp
    Process.kill("KILL", pid.to_i) unless pid.blank?
    ::ActiveRecord::Base.clear_all_connections!
    @thread_daemon = fork do
      $0 = process_name
      ::ActiveRecord::Base.establish_connection
      Process.setpriority(Process::PRIO_PROCESS, 0, @priority)
      @condition = true
      Signal.trap("TERM") { @condition = false }
      while @condition
        begin
          if Time.now >= @next_exec
            report = nil
            Benchmark.bm do |x|
              report = x.report {
                Configuration.do_reload
                @proc.call #if Rails.env.production?
                set_next_execution_time
                @daemon_logger.debug("[NEXT_EXEC_TIME] #{@next_exec}")
              }
            end
            @daemon_logger.info("[REPORT_DAEMON_EXEC] USER_TIME => #{report.utime}, TOTAL_TIME => #{report.total}, REAL_TIME => #{report.real}")
          end
        rescue Exception => e
          @daemon_logger.error(e)
        end
        to_sleep
      end
    end
  end

  def to_sleep
    time_to_sleep = ((@next_exec.to_i - Time.now.to_i) <= 0)? 0.5 : (@next_exec.to_i - Time.now.to_i)
    sleep [time_to_sleep, 5].min
  end

  def running?; @exec_as_process ? process_running? : thread_running?; end

  def process_running?; Process.wait2(pid, Process::WNOHANG).nil?; end

  def thread_running?; not @thread_daemon.status.nil?; end

  def name; @name; end

  def thread; @thread_daemon; end

  def join; @thread_daemon.join; end

  def is_a_process?; @exec_as_process; end

  def pid; @exec_as_process ? @thread_daemon : $?.pid; end

  def applying_changes?
    $mutex.synchronize {
      Configuration.is_apply_changes? ? $resource.wait($mutex) : $resource.signal
    }
  end

  # give all subclasses
  def self.descendants
    ObjectSpace.each_object(Class).select{ |klass| klass < self }.reject{|d| $daemon_configuration.has_key?(d.to_s.underscore) and not $daemon_configuration[d.to_s.underscore]['enabled'] }
  end
end

class DaemonApplyChange < DaemonTask

  def initialize
    @time_for_exec = { }
    @wait_for_apply_changes = false
    @need_to_reboot = false
    @proc = Proc.new { exec_daemon_apply_change }
    super
  end

  def exec_daemon_apply_change
    file_path = "#{DEPLOY_DIR}/tmp/apply_changes.lock"
    exec_command("rm #{file_path}") if File.exists?(file_path)

    $mutex.synchronize {
      if Configuration.daemon_reload
        # @need_to_reboot = true if Configuration.backup_restore == "boot"
        Configuration.first.update_attribute :daemon_reload, false
        @daemon_logger.debug("[START_APPLY_CHANGE]")
        boot
        @daemon_logger.debug("[FINISH_APPLY_CHANGE]")
        Configuration.first.update_attribute(:backup_restore, "reboot") if Configuration.backup_restore == "boot"
        $resource.signal
      end
    }
  end

end

class DaemonApplyChangeAutomatically < DaemonTask

  def initialize
    @time_for_exec = { }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_apply_change_automatically }
    super
  end

  def exec_daemon_apply_change_automatically
    output = Configuration.apply_changes_automatically!
    if output.to_a.empty?
      @daemon_logger.debug("[SEND_MESSAGE_FOR_APPLY_CHANGE]")
    else
      @daemon_logger.error_to_file(output.join(" "))
    end
  end

end

class DaemonCheckLink < DaemonTask

  def initialize
    @time_for_exec = { }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_check_link }
    @time_for_kill_dhcp = {}
    super
  end

  def exec_daemon_check_link
    exec_check_physical_links
    exec_check_links
  end

  def exec_check_physical_links
    changes = false
    Interface.all(:conditions => "vlan = 0").each do |i|
      current_physical_link = i.current_physical_link
      @daemon_logger.debug("[#{i.name}][CURRENT_LINK] #{i.physical_link}")

      if i.physical_link != current_physical_link
        changes = true
        @daemon_logger.debug("[#{i.name}][CHANGE_LINK] Before => #{i.physical_link}, After => #{current_physical_link}")
        i.physical_link = current_physical_link
        i.save(false)
      end
    end
    if Configuration.deliver_notifications and changes
      AppMailer.deliver_check_physical_links_email
      @daemon_logger.debug("[SEND_EMAIL]")
    end
  end

  def exec_check_links
    changes = false
    send_notification_mail = false
    providers = Provider.ready.all(:include => :interface)
    threads = {}

    providers.each do |p|
      threads[p.id] = Thread.new do
        # 1st by rate, if offline, then by ping
        # (r)etry=3 (t)iemout=500 (B)ackoff=1.5 (defualts)_
        Thread.current['online'] = p.is_online_by_rate? || `fping -a -S#{p.ip} #{PINGABLE_SERVERS} 2>/dev/null | wc -l`.chomp.to_i > 0
      end
    end

    # waith for threads
    # threads.each do |k,t| t.join end

    threads.each_value do |thread| thread.join end
    providers.each do |p|
      #puts "#{p.id} #{readme[p.id].first}"
      # online = threads[p.id]['online']
      # p.online = online
      # if not online and not p.notification_flag and p.offline_time > Configuration.notification_timeframe
      #   p.notification_flag = true
      #   send_notification_mail = true
      # elsif online and p.notification_flag
      #   p.notification_flag = false
      #   send_notification_mail = true
      # end
      #TODO refactorizar esto de alguna manera
      # la idea es killear el dhcp si esta caido más de 30 segundos
      # pero solo hacer kill en la primer pasada cada minuto, para darle tiempo de levantar
      # luego lo de abajo lo va a levantar
      # offline_time = p.offline_time
      # if p.kind == "dhcp" and offline_time > 30 and (offline_time-30)%120 < 16
      #   system "/usr/bin/pkill -f 'dhclient.#{p.interface.name}'"
      # end

      @time_for_kill_dhcp[p.id] = 0 unless @time_for_kill_dhcp.has_key?(p.id)

      p.online = threads[p.id]['online']

      @daemon_logger.debug("[PROVIDER_OFFLINE] #{p.class.name}:#{p.name}") unless p.online

      if p.online_changed? and p.online
        p.notification_flag = false
        send_notification_mail = true
        @daemon_logger.debug("[PROVIDER_ONLINE] #{p.class.name}:#{p.name}")
      elsif p.offline_time > Configuration.notification_timeframe and not p.notification_flag
        p.notification_flag = true
        send_notification_mail = true
      end

      p.save(false) if p.changed

      if p.kind == "dhcp"
        p.offline_time > 30 and Time.now.to_i > @time_for_kill_dhcp[p.id]
        @time_for_kill_dhcp[p.id] = (Time.now + 2.minutes).to_i
        @daemon_logger.debug("[KILL_DHCP] #{p.class.name}:#{p.name} try to kill #{Time.at(@time_for_kill_dhcp[p.id])}")
      end
    end

    Provider.with_klass_and_interface.each do |p|
      setup_provider_interface p, false unless p.online?
      update_provider_route p, false, false
    end
    ProviderGroup.enabled.each do |pg|
      update_provider_group_route pg, false, false
    end
    update_fallback_route false, false
    if send_notification_mail and Configuration.deliver_notifications
      AppMailer.deliver_check_links_email
      @daemon_logger.debug("[PROVIDER] send_notification")
    end
  end

end

class DaemonBackupRestore < DaemonTask

  def initialize
    @time_for_exec = { }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_backup_restore }
    super
  end

  def exec_daemon_backup_restore
    exec_backup_restore if Configuration.backup_restore
  end

  def exec_backup_restore
    case Configuration.backup_restore
    when "respawn_and_boot"
      @daemon_logger.debug("[RESTART_DAEMON]")
      $running = false
      Configuration.first.update_attribute :backup_restore, "boot"
    when "boot"
      Configuration.first.apply_changes
      @daemon_logger.debug("[SEND_MESSAGE_FOR_APPLY_CHANGE]")
    when "reboot"
      Configuration.first.update_attribute :backup_restore, nil
      if Configuration.backup_reboot
        Configuration.first.update_attribute :backup_reboot, false
        @daemon_logger.debug("[REBOOT_SYSTEM]")
        exec_command("/sbin/reboot")
      end
    end
    # when "boot"
    #   boot
    #   Configuration.first.update_attribute :last_changes_applied_at, Time.now
    #   Configuration.first.update_attribute :backup_restore, nil
    #   if Configuration.backup_reboot
    #     Configuration.first.update_attribute :backup_reboot, false
    #     system "/sbin/reboot"
    #   end
    # end
  end

end

class DaemonCheckBind < DaemonTask

  def initialize
    @time_for_exec = { }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_bind }
    super
  end

  def exec_daemon_bind
    exec_command("pgrep -x named || service bind9 start")
  end
end

class DaemonRedis < DaemonTask
 def initialize
   @time_for_exec = { }
   @wait_for_apply_changes = true
   @proc = Proc.new { exec_daemon_redis }
   @sample_count = 50
   super
 end

 def stop
   check_redis_service
   $redis.flushall
   super
 end

 def check_redis_service
   exec_command("/bin/ps -eo command | egrep \"^/usr/local/bin/redis-server.*\" &>/dev/null || /etc/init.d/redis start")
 end

 def exec_daemon_redis
   if check_redis_service
     interfaces_to_redis
     contracts_to_redis
   end
 end

 def interfaces_to_redis
   transactions = { :create => [] }
   @compact_keys = InterfaceSample.compact_keys
   Interface.all.each do |i|
     @relation  = i
     @redis_key = i.redis_key

     catchs = {}
     @compact_keys.each { |rkey| catchs[rkey[:name]] = i.send("#{rkey[:name]}_bytes") }
     @current_time = DateTime.now.to_i
     @timestamps = $redis.hkeys("#{@redis_key}_keys").to_a.sort
     round_robin()
     generate_sample(catchs)

     @daemon_logger.debug("[CounterSamplesRedis][Interface:#{i.id.to_s}][Value: #{@timestamps.size}]")

     if @timestamps.size >= 25
       samples = compact_to_db()
       transactions[:create] += samples[:create]
     end
   end

   unless transactions[:create].empty?
     InterfaceSample.massive_creation(transactions[:create])
     @daemon_logger.debug("[MassiveTransactions][InterfaceSampleModel][CREATE]")
   end
 end

 def contracts_to_redis
   transactions = { :create => [] }
   traffic_data_count = {}
   contract_connected = {}
   @compact_keys = ContractSample.compact_keys

   hfsc_class={"up" => {}, "down" => {}}
   File.read("| tc -s class show dev #{SequreispConfig::CONFIG["ifb_up"]}").scan(/class hfsc \d+\:([a-f0-9]*).*\n Sent (\d+) bytes/).each{|v| hfsc_class["up"][v[0]]=v[1]}
   File.read("| tc -s class show dev #{SequreispConfig::CONFIG["ifb_down"]}").scan(/class hfsc \d+\:([a-f0-9]*).*\n Sent (\d+) bytes/).each{|v| hfsc_class["down"][v[0]]=v[1]}

   @current_time = DateTime.now.to_i

   contracts = Contract.all(:include => :current_traffic)

   contracts.each do |c|
     # next if c.disabled?
     @relation  = c
     @redis_key = c.redis_key
     catchs = {}
     @compact_keys.each do |rkey|
       tc_class = c.send("tc_#{rkey[:sample]}")
       mark = tc_class[:mark]
       classid = "#{tc_class[:qdisc]}:#{mark}"
       parent  = "#{tc_class[:qdisc]}:#{tc_class[:parent]}"
       @daemon_logger.debug("[TC_CLASS][#{c.class.name}:#{c.id}] #{rkey[:sample]} class hfsc #{classid} parent #{parent} contract_mark #{mark}")
       catchs["#{rkey[:name]}"] = hfsc_class[rkey[:up_or_down]][mark].to_i
     end
     @timestamps = $redis.hkeys("#{@redis_key}_keys").to_a.sort
     round_robin()
     generate_sample(catchs)

     @daemon_logger.debug("[CounterSamplesRedis][Contract:#{c.id.to_s}][Value: #{@timestamps.size}]")
     if @timestamps.size >= 25
       samples = compact_to_db()
       transactions[:create] += samples[:create]
       traffic_data_count[c.current_traffic.id.to_s] = samples[:total] if samples[:total] > 0
       @daemon_logger.debug("[UpdateDataCount][Contract:#{c.id.to_s}][Value: #{traffic_data_count[c.current_traffic.id.to_s]}]") if samples[:total] > 0
       contract_connected[c.id.to_s] = samples[:total] > 0 ? 1 : 0
       @daemon_logger.debug("[UpdateContractConnected][Contract:#{c.id.to_s}][Value: #{contract_connected[c.id.to_s]}]") if samples[:total] > 0
     end
   end

   unless traffic_data_count.empty?
     @daemon_logger.debug("[MassiveTransactions]TrafficModel][Data_count]")
     Traffic.massive_sum( { :update_attr => "data_count",
                            :condition_attr => "id",
                            :values => traffic_data_count } )
   end

   unless contract_connected.empty?
     @daemon_logger.debug("[MassiveTransactions][ContractModel][Is_Connected]")
     Contract.massive_update( { :update_attr => "is_connected",
                                :condition_attr => "id",
                                :values => contract_connected } )
   end

   unless transactions[:create].empty?
     @daemon_logger.debug("[MassiveTransactions][ContractSampleModel][CREATE]")
     ContractSample.massive_creation(transactions[:create])
   end
 end

 def generate_sample(catchs)
   new_sample = {}
   new_key = "#{@redis_key}_#{@current_time}"

   last_time = @timestamps.last
   last_key = last_time.nil? ? nil : "#{@redis_key}_#{last_time}"
   total_seconds = last_time.nil? ? 1 : (@current_time.to_f - last_time.to_f)

   catchs.each do |prio_key, current_total|
     new_sample[prio_key] = { :instant => 0, :total_bytes => current_total }
     unless last_key.nil?
       last_total = $redis.hget("#{last_key}", "#{prio_key}_total_bytes").to_i
       new_sample[prio_key][:instant] = (current_total < last_total ? current_total : (current_total - last_total) )
     end
     $redis.hmset("#{new_key}", "#{prio_key}_instant", new_sample[prio_key][:instant], "#{prio_key}_total_bytes", current_total )
   end

   $redis.hmset("#{new_key}", "time", @current_time)
   $redis.hmset("#{new_key}", "total_seconds", total_seconds)
   $redis.hmset("#{@redis_key}_keys", @current_time.to_s, new_key)

   @daemon_logger.debug("[SAMPLE_GENERATED][#{@relation.class.name}:#{@relation.id}] last_sample_redis: #{$redis.hgetall(last_key).inspect}, new_sample_redis: #{$redis.hgetall(new_key).inspect}")
 end

 def next_init_time_new_sample(time_period, period, first_redis_key)
   next_time = $redis.hget(@redis_key, "period_#{period}")
   if next_time.nil?
     last_sample_in_db = ContractSample.all(:conditions => {:period => period, :contract_id => @relation.id} ).last
     next_time = if last_sample_in_db.nil?
                   (Time.at($redis.hget("#{first_redis_key}", "time").to_i).change(:sec => 0)).to_i
                 else
                   (last_sample_in_db.sample_number.to_i + time_period)
                 end
   end
   next_time.to_i
 end

 def compact_to_db
   samples = { :create => [], :total => 0 }
   time_period = "#{@relation.class.name}Sample".constantize::CONF_PERIODS[:period_0][:time_sample]
   period = "#{@relation.class.name}Sample".constantize::CONF_PERIODS[:period_0][:period_number]
   date_keys = @timestamps[0..12]
   time_last_sample  = date_keys.last.to_i #LA FECHA DE LA MAS NUEVA

   @init_time_new_sample = next_init_time_new_sample(time_period, period, "#{@redis_key}_#{date_keys.first}")
   @end_time_new_sample  = @init_time_new_sample + (time_period - 1)

   while (not date_keys.empty?) and time_last_sample >= @end_time_new_sample
     keys_to_delete = []
     sample_empty = Hash[@compact_keys.collect{|k| [k[:name], 0] }]
     samples_to_compact = [sample_empty]

     new_sample = { :period => period,
                    :sample_time => Time.at(@init_time_new_sample).utc.to_s(:db),
                    :sample_number => @init_time_new_sample.to_s,
                    "#{@relation.class.name.downcase}_id".to_sym => @relation.id }

     @daemon_logger.debug("[PeriodForNewSample][#{@relation.class.name}:#{@relation.id}] (#{Time.at(@init_time_new_sample)}) - (#{Time.at(@end_time_new_sample)}")

     date_keys.each do |key|
       sample_key = "#{@redis_key}_#{key}"
       sample = {}
       time = key.to_i
       if time <= @end_time_new_sample
        @compact_keys.each { |rkey| sample[rkey[:name]] = $redis.hget(sample_key, "#{rkey[:name]}_instant").to_i }
         @daemon_logger.debug("[SamplesTimesRedis][#{@relation.class.name}:#{@relation.id}][YES] (#{Time.at(time)}) ---> #{new_sample.inspect}")
         keys_to_delete << key
         samples_to_compact << sample
       else
         @daemon_logger.debug("[SamplesTimesRedis][#{@relation.class.name}:#{@relation.id}][NO] (#{Time.at(time)})")
       end
     end

     data_acummulated = samples_to_compact.sum
     samples[:total] += data_acummulated.values.sum
     samples[:create] << new_sample.merge((data_acummulated / time_period * 8))
     keys_to_delete.each do |key|
       $redis.hdel("#{@redis_key}_keys", key)
       $redis.del("#{@redis_key}_#{key}")
     end
     @init_time_new_sample += time_period
     @end_time_new_sample  += time_period
   end

   @daemon_logger.debug("[UPDATE_LAST_SAMPLE][#{@relation.class.name}:#{@relation.id}][Period:#{period}][SAMPLE_NUMBER:#{@init_time_new_sample}](#{Time.at(@init_time_new_sample)})")
   $redis.hmset(@redis_key, "period_#{period}", @init_time_new_sample)
   samples
 end

 def round_robin
   if @timestamps.size >= @sample_count
     timestamp = @timestamps.shift
       $redis.hdel("#{@redis_key}_keys", timestamp)
       $redis.del("#{@redis_key}_#{timestamp}")
     @daemon_logger.debug("[DROP_FIRST_SAMPLE][#{@relation.class.name}:#{@relation.id}][Sample: #{timestamp}]")
   end
 end

end

class DaemonCompactSamples < DaemonTask

  def initialize
    @time_for_exec = { }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_compact_samples }
    super
  end

  def models_to_compact; ["contract", "interface"]; end

  # def create_last_samples_time_into_redis
  #   @klass.last_samples_created.each do |period, values|
  #     values.each do |id, sample_time|
  #       redis_key = @model.camelize.constantize.redis_key(id)
  #       next_init_sample_time = sample_time + @klass::CONF_PERIODS[period.to_sym][:time_sample]
  #       $redis.hmset(redis_key, period, next_init_sample_time)
  #     end
  #   end
  #   $redis.set("compactor_up_to_date", true)
  # end

  def exec_daemon_compact_samples
    models_to_compact.each do |model|
      transactions = { :create => [],:destroy => [] }
      @klass = "#{model}_sample".camelize.constantize
      @model = model
      numbers_of_period =  @klass::CONF_PERIODS.count

#      create_last_samples_time_into_redis if $redis.get("compactor_up_to_date").nil?

      @samples_to_compact = @klass.samples_to_compact

      numbers_of_period.times do |i|
        @samples_to_compact["period_#{i}".to_sym].each do |model_id, samples|
          @relation_id = model_id
          @daemon_logger.debug("[NeedCompact][#{@klass.name}][#{@model.camelize}:#{@relation_id}][PERIOD:#{i}][SAMPLES_TO_COMPACT] #{samples.collect(&:id).inspect}")
          transactions += compact(i.next, samples)
        end
      end

      unless transactions[:destroy].empty?
        @daemon_logger.debug("[MassiveTransactions][#{@klass}Model][DELETE]")
        @klass.delete_all("id IN (#{transactions[:destroy].collect(&:id).join(',')})")
      end

      unless transactions[:create].empty?
        @daemon_logger.debug("[MassiveTransactions][#{@klass}Model][CREATE]")
        @klass.massive_creation(transactions[:create])
      end
    end
  end

  private

  def next_init_time_new_sample(redis_key, time_period, period, sample_time)
    next_time = $redis.hget(redis_key, "period_#{period}")
    next_time = LastSample.find_or_create_by_period_and_model_type_and_model_id(period, @model.camelize, @relation_id, :sample_number => sample_time).sample_number if next_time.nil?
    next_time.to_i
  end

  def compact(period, samples_to_compact)
    samples = { :create => [], :destroy => [], :last_samples => [] }
    time_period = @klass::CONF_PERIODS["period_#{period}".to_sym][:time_sample]
    time_samples = samples_to_compact.collect(&:sample_number).map(&:to_i).sort
    last_sample_time = time_samples.last
    redis_key = @model.camelize.constantize.redis_key(@relation_id)

    init_time_new_sample = next_init_time_new_sample(redis_key, time_period, period, time_samples.first)
    end_time_new_sample = init_time_new_sample + (time_period - @klass::CONF_PERIODS["period_#{period-1}".to_sym][:time_sample])

    @daemon_logger.debug("[PERIOD:#{period}][#{@model.camelize}:#{@relation_id}][INIT_SAMPLE_FRAME] #{Time.at(init_time_new_sample)} - [END_SAMPLE_FRAME] #{Time.at(end_time_new_sample)} #{@model.camelize}:#{@relation_id}")
    @daemon_logger.debug("[PERIOD:#{period}][#{@model.camelize}:#{@relation_id}][LAST_SAMPLE_TIME] #{@model.camelize}:#{@relation_id} #{Time.at(last_sample_time)}")

    while end_time_new_sample <= last_sample_time
      @daemon_logger.debug("[PERIOD:#{period}][#{@model.camelize}:#{@relation_id}][RANGE_FOR_FRAME] #{Time.at(init_time_new_sample)} - #{Time.at(end_time_new_sample)}")

      range = (init_time_new_sample..end_time_new_sample)

      selected_samples = samples_to_compact.select { |sample| range.include?(sample.sample_number.to_i) }

      unless selected_samples.empty?
        new_sample = { :period => period,
                       :sample_time => Time.at(init_time_new_sample).utc.to_s(:db),
                       :sample_number => init_time_new_sample,
                       "#{@model}_id".to_sym => @relation_id }

        @daemon_logger.debug("[PERIOD:#{period}][#{@model.camelize}:#{@relation_id}][SELECTED_SAMPLES] #{selected_samples.collect(&:sample_time).inspect}")

        samples[:create] << new_sample.merge(@klass.compact(period, selected_samples))
        samples[:destroy] += selected_samples
      end

      init_time_new_sample += time_period
      end_time_new_sample += time_period
    end

    LastSample.update_all("sample_number = #{init_time_new_sample}", { :period => period, :model_type => @model.camelize, :model_id => @relation_id })
    @daemon_logger.debug("[PERIOD:#{period}][#{@model.camelize}:#{@relation_id}][UPDATE_LAST_SAMPLE_MODEL] sample_number = #{init_time_new_sample}")
    $redis.hmset(redis_key, "period_#{period}", init_time_new_sample)
    samples
  end
end

class DaemonSynchronizeTime < DaemonTask
  def initialize
    @time_for_exec = { }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_sync_time }
    super
  end

  def exec_daemon_sync_time
    exec_command("ntpdate pool.ntp.org")
    exec_command("hwclock --systohc")
  end
end
