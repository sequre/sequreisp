if Rails.env.development?
  require 'sequreisp_logger'
  require 'sequreisp_constants'
  #Thread::abort_on_exception = true

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
  @@threads ||= []

  def initialize
    @thread_daemon = nil
    @name = self.class.to_s
    @conf_daemon = $daemon_configuration[@name.underscore]
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

  def join
    @thread_daemon.join
  end

  def stop
    begin
      @daemon_logger.debug("[REMOVE_DAEMON_LOG_FILE]")
      @daemon_logger.remove_log_file
      @thread_daemon.exit
      @daemon_logger.info("[STOP]")
    rescue Exception => e
      @daemon_logger.error(e)
    end
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

  def start
    @thread_daemon = Thread.new do
      @@threads << self
      Thread.current["name"] = @name
      Thread.current.priority = @priority
      loop do
        begin
          if Time.now >= @next_exec
            Configuration.do_reload
            @daemon_logger.info("[EXEC_THREAD_AT] #{@next_exec}")
            set_next_execution_time
            applying_changes? if @wait_for_apply_changes and Rails.env.production?
            @proc.call #if Rails.env.production?
            @daemon_logger.debug("[NEXT_EXEC_TIME] #{@next_exec}")
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

  def state
    # "run"       thread is runnable
    # "sleep"     thread is sleeping
    # "aborting"  thread is aborting
    # false       thread terminated normally
    # nil         thread terminated abnormally
    @thread_daemon.status
  end

  def name
    @name
  end

  def thread
    @thread_daemon
  end

  #Only works in development
  def self.threads
    @@threads
  end

  def applying_changes?
    $mutex.synchronize {
      Configuration.is_apply_changes? ? $resource.wait($mutex) : $resource.signal
    }
  end

  # give all subclasses
  def self.descendants
    # $daemon_configuration.select{ |key, value| value['enabled'] }.collect{ |d| first.camelize }
    (ObjectSpace.each_object(Class).select{ |klass| klass < self }.map(&:to_s) & $daemon_configuration.reject{|key, value| not value['enabled'] }.keys.map(&:camelize)).map(&:constantize)
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

 def exec_daemon_redis
   result = exec_command("/bin/ps -eo command | egrep \"^/usr/local/bin/redis-server *:6379\" &>/dev/null || /etc/init.d/redis start")
   if result[:status]
     interfaces_to_redis
     contracts_to_redis
   end
 end

 def data_count(contracts, data_counting)
   Contract.transaction {
     contracts.each do |c|
       unless data_counting[c.id.to_s].nil?
         c.is_connected = data_counting[c.id.to_s].zero? ? false : true
         traffic_current = c.current_traffic || c.create_traffic_for_this_period
         value_before_update = "#{traffic_current.data_count} + #{data_counting[c.id.to_s]}"
         traffic_current.data_count += data_counting[c.id.to_s]
         traffic_current.save
         c.current_traffic = traffic_current
         @daemon_logger.debug("[UpdateDataCounting][#{c.class.name}:#{c.id}] #{value_before_update} = #{c.current_traffic.data_count}")
         c.save
       end
     end
   }
 end

 def interfaces_to_redis
   transactions = { :create => [] }
   @compact_keys = InterfaceSample.compact_keys
   counter_key = "interface_counters"
   Interface.all.each do |i|
     @relation = i
     @redis_key  = i.redis_key
     $redis.hset(counter_key, i.id.to_s, 0) unless $redis.hexists(counter_key, i.id.to_s)
     round_robin()
     catchs = {}
     @compact_keys.each { |rkey| catchs[rkey[:name]] = i.send("#{rkey[:name]}_bytes") }
     counter = $redis.hget(counter_key, i.id.to_s).to_i
     generate_sample(catchs)
     $redis.hincrby(counter_key, i.id.to_s, 1)
     if counter == 13
       samples = compact_to_db()
       transactions[:create] += samples[:create]
       $redis.hset(counter_key, i.id.to_s, 0)
     end
   end

   InterfaceSample.transaction {
     transactions[:create].each do |transaction|
       sample = InterfaceSample.create(transaction)
       @daemon_logger.debug("[InterfaceTransactions][CREATE][#{sample.class.name}:#{sample.id}] #{sample.inspect}")
     end
   }
 end

 def contracts_to_redis
   transactions = { :create => [] }
   data_counting = {}
   @compact_keys = ContractSample.compact_keys
   counter_key = "contract_counters"
   hfsc_class = { "up" => `/sbin/tc -s class show dev #{SequreispConfig::CONFIG["ifb_up"]}`.split("\n\n"),
                  "down" => `/sbin/tc -s class show dev #{SequreispConfig::CONFIG["ifb_down"]}`.split("\n\n") }


   contracts = Contract.all(:include => :current_traffic)

   contracts.each do |c|
     next if c.disabled?
     @relation = c
     @redis_key  = c.redis_key
     $redis.hset(counter_key, c.id.to_s, 0) unless $redis.hexists(counter_key, c.id.to_s)
     round_robin()
     catchs = {}
     @compact_keys.each do |rkey|
       tc_class = c.send("tc_#{rkey[:sample]}")
       classid = "#{tc_class[:qdisc]}:#{tc_class[:mark]}"
       parent  = "#{tc_class[:qdisc]}:#{tc_class[:parent]}"
       contract_class = hfsc_class[rkey[:up_or_down]].select{|k| k.include?("class hfsc #{classid} parent #{parent}")}.first
       catchs["#{rkey[:name]}"] = contract_class.split("\n").select{|k| k.include?("Sent ")}.first.split(" ")[1].to_i
     end
     counter = $redis.hget(counter_key, c.id.to_s).to_i
     generate_sample(catchs)
     $redis.hincrby(counter_key, c.id.to_s, 1)
     if counter == 13
       samples = compact_to_db()
       transactions[:create] += samples[:create]
       data_counting[c.id.to_s] = samples[:total]
       $redis.hset(counter_key, c.id.to_s, 0)
     end
   end

   data_count(contracts, data_counting)

   ContractSample.transaction {
     transactions[:create].each do |transaction|
       sample = ContractSample.create(transaction)
       @daemon_logger.debug("[ContractTransactions][CREATE][#{sample.class.name}:#{sample.id}] #{sample.inspect}")
     end
   }
 end

 def round_robin
   date_keys =$redis.keys("#{@redis_key}_*").sort
   if date_keys.count == @sample_count
     $redis.del(date_keys.first)
     @daemon_logger.debug("[DROP_FIRST_SAMPLE][#{@relation.class.name}:#{@relation.id}]")
   end
 end

 def generate_sample(catchs)
   new_sample = {}
   current_time = DateTime.now.to_i
   new_key = "#{@redis_key}_#{current_time}"
   last_key = $redis.keys("#{@redis_key}_*").sort.last
   last_time = $redis.hget("#{last_key}", "time").to_i
   total_seconds = (current_time - last_time).zero? ? 1 : (current_time - last_time)
   $redis.hmset("#{new_key}", "time", current_time)
   $redis.hmset("#{new_key}", "total_seconds", total_seconds)

   catchs.each do |prio_key, current_total|
     new_sample[prio_key] = { :instant => 0, :total_bytes => current_total }
     unless last_key.nil?
       last_total = $redis.hget("#{last_key}", "#{prio_key}_total_bytes").to_i
       new_sample[prio_key][:instant] = (current_total < last_total ? current_total : (current_total - last_total) )
     end
     $redis.hmset("#{new_key}", "#{prio_key}_instant", new_sample[prio_key][:instant], "#{prio_key}_total_bytes", current_total )
   end

   @daemon_logger.debug("[SAMPLE_GENERATED][#{@relation.class.name}:#{@relation.id}] last_sample_redis: #{$redis.hgetall(last_key).inspect}, new_sample_redis: #{$redis.hgetall(new_key).inspect}")
 end

 def compact_to_db
   samples = { :create => [], :total => 0 }
   time_period = ContractSample::CONF_PERIODS[:period_0][:time_sample]
   period = ContractSample::CONF_PERIODS[:period_0][:period_number]
   date_keys = $redis.keys("#{@redis_key}_*").sort
   time_last_sample  = $redis.hget("#{date_keys.last}", "time").to_i #LA FECHA DE LA MAS NUEVA
   @init_time_new_sample = (ContractSample.all(:conditions => {:period => period, :contract_id => @relation.id} ).last.sample_number + time_period) rescue false ||
                           (Time.at($redis.hget("#{date_keys.first}", "time").to_i).change(:sec => 0)).to_i
   @end_time_new_sample  = @init_time_new_sample + (time_period - 1)

   while (not date_keys.empty?) and time_last_sample >= @end_time_new_sample
     keys_to_delete = []
     samples_to_compact = []

     new_sample = { :period => period,
                    :sample_time => Time.at(@init_time_new_sample),
                    :sample_number => @init_time_new_sample.to_s,
                    "#{@relation.class.name.downcase}_id".to_sym => @relation.id }

     @daemon_logger.debug("[PeriodForNewSample][#{@relation.class.name}:#{@relation.id}] (#{Time.at(@init_time_new_sample)}) - (#{Time.at(@end_time_new_sample)}")

     date_keys.each do |key|
       sample = {}
       time = $redis.hget("#{key}", "time").to_i
       if time <= @end_time_new_sample
         @compact_keys.each { |rkey| sample[rkey[:name]] = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i }
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
     keys_to_delete.each { |key| $redis.del(key) }
     @init_time_new_sample += time_period
     @end_time_new_sample  += time_period
   end
   samples
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

  def exec_daemon_compact_samples
    models_to_compact.each do |model|
      transactions = { :create => [],:destroy => [] }
      @klass = "#{model}_sample".camelize.constantize
      @model = model
      @sample_conf = @klass.sample_conf
      numbers_of_period =  @sample_conf.count
      numbers_of_period.times do |i|
        @sample_conf["period_#{i}".to_sym][:samples_to_compact].each do |key, values|
          @relation_id = key
          last_sample_time_for_next_period = @sample_conf["period_#{i.next}".to_sym][:last_sample_time][key]
          @daemon_logger.debug("[NeedCompact][#{@klass.name}] #{model.camelize}:#{key})")
          transactions += compact(i.next, values, last_sample_time_for_next_period)
        end
      end
      @klass.transaction {
        transactions[:destroy].each do |transaction|
          @daemon_logger.debug("[#{@klass.name}Transactions][#{model.class.name}:#{transaction.object.id}][DESTROY] #{transaction.inspect}")
          transaction.delete
        end
        transactions[:create].each do |transaction|
          sample = @klass.create(transaction)
          @daemon_logger.debug("[#{@klass.name}Transactions][#{model.class.name}:#{sample.object.id}][CREATE] #{sample.inspect}")
        end
      }
    end
  end

  private

  def compact(period, data, time_sample=nil)
    samples = { :create => [], :destroy => [] }
    time_period = (60 * @sample_conf["period_#{period}".to_sym][:time_sample])
    time_samples = data.collect(&:sample_number).map(&:to_i).sort

    init_time_new_sample = time_sample.nil? ? time_samples.first : (time_sample + time_period)
    end_time_new_sample = init_time_new_sample + (time_period - 1)
    range = (init_time_new_sample..end_time_new_sample)
    sample_time = Time.at(init_time_new_sample)
    @daemon_logger.debug("[Range](#{@model.class.name}:#{@relation_id} (#{init_time_new_sample} - #{end_time_new_sample}) ---> #{Time.at(init_time_new_sample)} - #{Time.at(end_time_new_sample)}")
    data.each do |k|
      if range.include?(k.sample_number.to_i)
        samples[:destroy] << k
        @daemon_logger.debug("[DataSelected][#{@klass.name}][Compact] (#{@model.class.name}:#{@relation_id}, :sample_number => #{k.sample_number} --> #{k.inspect}")
      else
        @daemon_logger.debug("[DataSelected][#{@klass.name}][NoCompact] (#{@model.class.name}:#{@relation_id}, :sample_number => #{k.sample_number} --> #{k.inspect}")
      end
    end
    new_sample = @klass.compact(period, samples[:destroy])
    samples[:create] << new_sample.merge({:period => period, :sample_time => sample_time, :sample_number => init_time_new_sample, "#{@model}_id".to_sym => @relation_id })
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

#########################################################
#
#
#########################################################
