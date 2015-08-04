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
$resource = ConditionVariable.new
$redis_mutex = Mutex.new

class DaemonTask

  @@threads ||= []

  def initialize
    @thread_daemon = nil
    @name = self.class.to_s.underscore.humanize
    @log_path = "#{DEPLOY_DIR}/tmp/#{self.class.to_s.underscore.downcase}"
    FileUtils.touch @log_path
    set_next_exec
  end

  def verbose?
    File.exists?("#{DEPLOY_DIR}/tmp/verbose")
  end

  def stop
    begin
      @thread_daemon.exit
    rescue Exception => e
      log_rescue("[Daemon] ERROR Thread #{name}", e)
    ensure
      FileUtils.rm(@log_path) if File.exist?(@log_path)
      log "[Daemon] STOP thread #{name}"
    end
  end

  def set_next_exec
    if not defined?(@next_exec)
      @next_exec = @time_for_exec.has_key?(:begin_in) ? Time.parse(@time_for_exec[:begin_in], Time.new) : Time.now
      @next_exec += @time_for_exec[:frecuency] if Time.now > @next_exec
    else
      while @next_exec <= Time.now
        @next_exec += @time_for_exec[:frecuency]
      end
    end
  end

  def start
    @thread_daemon = Thread.new do
      @@threads << self
      log "[Daemon] START Thread #{name}"
      Thread.current["name"] = @name
      loop do
        begin
          if Time.now >= @next_exec
            Configuration.do_reload
            set_next_exec
            applying_changes? if @wait_for_apply_changes and Rails.env.production?
            @proc.call if Rails.env.production?
            log "[Daemon] EXEC Thread #{name}" if verbose?
          end
        rescue Exception => e
          log_rescue("[Daemon] ERROR Thread #{name}", e)
          log_rescue_file(@log_path, e)
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
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end

end

class DaemonApplyChange < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 1.seconds }
    @wait_for_apply_changes = false
    @proc = Proc.new { exec_daemon_apply_change }
    super
  end

  def exec_daemon_apply_change
    $mutex.synchronize {
      if Configuration.daemon_reload
        Configuration.first.update_attribute :daemon_reload, false
        boot
        $resource.signal
      end
    }
  end

end

class DaemonApplyChangeAutomatically < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 1.hour }
    @wait_for_apply_changes = false
    @proc = Proc.new { exec_daemon_apply_change_automatically }
    super
  end

  def exec_daemon_apply_change_automatically
    $mutex.synchronize {
      Configuration.apply_changes_automatically!
      $resource.signal
    }
  end

end

class DaemonCheckLink < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 10.seconds }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_check_link }
    super
  end

  def exec_daemon_check_link
    exec_check_physical_links
    exec_check_links
  end

  def exec_check_physical_links
    changes = false
    readme = []
    writeme = []
    pid = []
    Interface.all(:conditions => "vlan = 0").each do |i|
      physical_link = i.current_physical_link
      if i.physical_link != physical_link
        changes = true
        i.physical_link = physical_link
        i.save(false)
        #TODO loguear el cambio de estado en una bitactora
      end
    end
    begin
      if Configuration.deliver_notifications and changes
        AppMailer.deliver_check_physical_links_email
      end
    rescue => e
      log_rescue("[Daemon] ERROR Thread #{name}", e)
      # Rails.logger.error "ERROR in lib/sequreisp.rb::check_physical_links e=>#{e.inspect}"
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
    threads.each do |k,t| t.join end

    providers.each do |p|
      #puts "#{p.id} #{readme[p.id].first}"
      online = threads[p.id]['online']
      p.online = online
      #TODO loguear el cambio de estado en una bitactora

      if !online and !p.notification_flag and p.offline_time > Configuration.notification_timeframe
        p.notification_flag = true
        send_notification_mail = true

      elsif online and p.notification_flag
        p.notification_flag = false
        send_notification_mail = true
      end

      p.save(false) if p.changed?

      #TODO refactorizar esto de alguna manera
      # la idea es killear el dhcp si esta caido más de 30 segundos
      # pero solo hacer kill en la primer pasada cada minuto, para darle tiempo de levantar
      # luego lo de abajo lo va a levantar
      offline_time = p.offline_time
      if p.kind == "dhcp" and offline_time > 30 and (offline_time-30)%120 < 16
        system "/usr/bin/pkill -f 'dhclient.#{p.interface.name}'"
      end
    end

    Provider.with_klass_and_interface.each do |p|
      setup_provider_interface p, false if not p.online?
      update_provider_route p, false, false
    end
    ProviderGroup.enabled.each do |pg|
      update_provider_group_route pg, false, false
    end
    update_fallback_route false, false
    begin
      if send_notification_mail and Configuration.deliver_notifications
        AppMailer.deliver_check_links_email
      end
    rescue => e
      log_rescue("[Daemon] ERROR Thread #{name}", e)
      # Rails.logger.error "ERROR in lib/sequreisp.rb::check_links(AppMailer) e=>#{e.inspect}"
    end
  end

end

class DaemonBackupRestore < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 10.seconds }
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

# class DaemonDataCounting < DaemonTask

#   def initialize
#     @time_for_exec = { :frecuency => 60.seconds }
#     @max_current_traffic_count = 1000 / 8 * 1024 * 1024 * 60
#     @wait_for_apply_changes = true
#     @proc = Proc.new { exec_daemon_data_counting }
#     super
#   end

#   def exec_daemon_data_counting
#     exec_data_counting
#   end

#   def exec_data_counting
#     hash_count = { "up" => {}, "down" => {} }
#     contracts = Contract.not_disabled(:include => :current_traffic)
#     contract_count = contracts.count
#     parse_data_count(contracts, hash_count)

#     ActiveRecord::Base.transaction do
#       begin
#         File.open(File.join(DEPLOY_DIR, "log/data_counting.log"), "a") do |f|
#           contracts.each do |c|
#             traffic_current = c.current_traffic || c.create_traffic_for_this_period
#             c.is_connected = false

#             Configuration::COUNT_CATEGORIES.each do |category|
#               data_total = 0
#               data_total += hash_count["up"][c.ip][category].to_i if hash_count["up"].has_key?(c.ip)
#               data_total += hash_count["down"][c.ip][category].to_i if hash_count["down"].has_key?(c.ip)

#               if data_total != 0
#                 c.is_connected = true
#                 current_traffic_count = traffic_current.data_count
#                 eval("traffic_current.#{category} += data_total") if data_total <= @max_current_traffic_count

#                 #Log data counting
#                 # if contract_count <= 300 and Rails.env.production?
#                 #   if (data_total >= 7864320) or (eval("c.current_traffic.#{category} - current_traffic_count >= 7864320")) or (eval("(c.current_traffic.#{category} - data_total) != current_traffic_count"))
#                 #     f.puts "#{Time.now.strftime('%d/%m/%Y %H:%M:%S')}, ip: #{c.ip}(#{c.current_traffic.id}), Category: #{category}, Data Count: #{tmp},  Data readed: #{hash_count[c.ip]}, Data Accumulated: #{c.current_traffic.data_count}"
#                 #   end
#                 # end
#                 traffic_current.save if traffic_current.changed?
#               end
#             end

#             c.save if c.changed?
#           end
#         end
#       rescue => e
#         log_rescue("[Daemon] ERROR Thread #{name}", e)
#         # Rails.logger.error "ERROR TrafficDaemonThread: #{e.inspect}"
#       ensure
#         time_last = Time.now
#         system "iptables -t filter -Z" if Rails.env.production?
#       end
#     end
#   end

#   def parse_data_count(contracts, hash_count)
#     if SequreispConfig::CONFIG["demo"]
#       contracts.all.each do |contract|
#         hash_count["up"][contract.ip]["data_count"] = rand(1844674)
#         hash_count["down"][contract.ip]["data_count"] = rand(1844674)
#       end
#     else
#       begin
#         # [["bytes", "ip", "up|down", "data_count"], ["bytes", "ip", "up|down", "data_count"]]
#         File.read("|iptables-save -t filter -c").scan(/\[.*:(\d+)\].*comment \"data-count-(.*)-(.*)-(.*)\"/).each do |line|
#           # line[0] => byte's, line[1] => i1p, line[2] => up | down, line[3] => category, where the category name is the same with  any traffic attribute
#           if line[0] != "0"
#             hash_count[line[2]][line[1]] = {}
#             hash_count[line[2]][line[1]][line[3]] = line[0]
#           end
#         end
#       rescue => e
#         log_rescue("[Daemon] ERROR Thread #{name}", e)
#       end
#     end
#   end

# end


# class DaemonRrdFeed < DaemonTask

#   require 'rrd'
#   #require 'ruby-debug'
#   # IFB_UP="ifb0"
#   # IFB_DOWN="ifb1"
#   RRD_DIR=RAILS_ROOT + "/db/rrd"
#   INTERVAL=300

#   def initialize
#     @time_for_exec = { :frecuency => 5.minutes }
#     @wait_for_apply_changes = true
#     @proc = Proc.new { exec_daemon_rrd_feed unless Configuration.in_safe_mode? }
#     super
#   end

#   def exec_daemon_rrd_feed
#     exec_rrd_feed
#   end

#   def exec_rrd_feed
#     client_up = tc_class(IFB_UP)
#     client_down = tc_class(IFB_DOWN)
#     time_c = Time.now

#     # if Configuration.use_global_prios
#     #   p_up, p_down = {}, {}
#     #   Interface.all(:conditions => { :kind => "lan" }).each do |i|
#     #     p_down = tc_class i.name, p_down
#     #   end
#     #   Provider.enabled.all.each do |p|
#     #     p_up = tc_class p.link_interface, p_up
#     #   end
#     # else
#     p_up, p_down = [], []
#     Provider.enabled.all.each do |p|
#       p_up[p.id] = File.open("/sys/class/net/#{p.interface.name}/statistics/tx_bytes").read.chomp.to_i rescue 0
#       p_down[p.id] = File.open("/sys/class/net/#{p.interface.name}/statistics/rx_bytes").read.chomp.to_i rescue 0
#     end
#     # end
#     time_p = Time.now

#     i_up, i_down = [], []
#     Interface.all.each do |i|
#       i_up[i.id] = File.open("/sys/class/net/#{i.name}/statistics/tx_bytes").read.chomp rescue 0
#       i_down[i.id] = File.open("/sys/class/net/#{i.name}/statistics/rx_bytes").read.chomp rescue 0
#     end
#     time_i = Time.now

#     # SECOND we made the updates
#     Contract.all.each do |c|
#       # if Configuration.use_global_prios
#       #   rrd_update c, time_c, client_down["1"][c.class_hex], 0, client_up["1"][c.class_hex], 0
#       # else
#       rrd_update c, time_c, client_down["1"][c.class_prio2_hex], client_down["1"][c.class_prio3_hex], client_up["1"][c.class_prio2_hex], client_up["1"][c.class_prio3_hex]
#       # end
#     end

#     ProviderGroup.enabled.each do |pg|
#       pg_down_prio2 = pg_down_prio3 = pg_up_prio2 = pg_up_prio3 = 0
#       pg.providers.enabled.each do |p|
#         p_down_prio2 = p_down_prio3 = p_up_prio2 = p_up_prio3 = 0
#         # if Configuration.use_global_prios
#         #   p_down_prio2 = p_down[p.class_hex]["a"] + p_down[p.class_hex]["b"] rescue 0
#         #   p_down_prio3 = p_down[p.class_hex]["c"] rescue 0
#         #   # dynamic ifaces like ppp could not exists, so we need to rescue an integer
#         #   # if we scope providers by ready and online, we may skip traffic to be logged
#         #   # and the ppp iface could go down betwen check and the read
#         #   p_up_prio2 = (p_up[p.class_hex]["a"] + p_up[p.class_hex]["b"]) rescue 0
#         #   p_up_prio3 = p_up[p.class_hex]["c"] rescue 0
#         # else
#         p_up_prio2 = p_up[p.id]
#         p_down_prio2 = p_down[p.id]
#         # end
#         rrd_update p, time_p, p_down_prio2, p_down_prio3, p_up_prio2, p_up_prio3
#         pg_down_prio2 += p_down_prio2
#         pg_down_prio3 += p_down_prio3
#         pg_up_prio2 += p_up_prio2
#         pg_up_prio3 += p_up_prio3
#       end
#       rrd_update pg, time_p, pg_down_prio2, pg_down_prio3, pg_up_prio2, pg_up_prio3
#     end

#     Interface.all.each do |i|
#       rrd_update i, time_i, i_down[i.id], 0, i_up[i.id], 0
#     end
#   end

#   def rrd_create(path, time)
#     RRD::Wrapper.create '--start', (time - 60.seconds).strftime("%s"), path,
#     "-s", "#{INTERVAL.to_s}",
#     # max = 1*1024*1024*1024*600 = 1Gbit/s * 600s
#     "DS:down_prio:DERIVE:600:0:644245094400",
#     "DS:down_dfl:DERIVE:600:0:644245094400",
#     "DS:up_prio:DERIVE:600:0:644245094400",
#     "DS:up_dfl:DERIVE:600:0:644245094400",
#     #(24x60x60/300)*30dias
#     "RRA:AVERAGE:0.5:1:8640",
#     #(24x60x60x30/300)*12meses
#     "RRA:AVERAGE:0.5:30:3456",
#     #(24x60x60x30x12/300)*10años
#     "RRA:AVERAGE:0.5:360:2880"
#   end

#   def rrd_update(o, time, down_prio, down_dfl, up_prio, up_dfl)
#     log("[Daemon][RRD][rrd_update] o=#{o.name}, time=#{time}, down_prio=#{down_prio}, down_dfl=#{down_dfl}, up_prio=#{up_prio}, up_dfl=#{up_dfl}") if verbose?
#     rrd_path = RRD_DIR + "/#{o.class.name}.#{o.id.to_s}.rrd"
#     rrd_create(rrd_path, time) unless File.exists?(rrd_path)
#     RRD::Wrapper.update rrd_path, "-t", "down_prio:down_dfl:up_prio:up_dfl", "#{time.strftime("%s")}:#{down_prio}:#{down_dfl}:#{up_prio}:#{up_dfl}"
#     #puts "#{o.klass.number.to_s(16) rescue nil} #{rrd_path} #{time.strftime("%s")}:#{down_prio}:#{down_dfl}:#{up_prio}:#{up_dfl}"
#   end

#   def tc_class(iface, karray = {})
#     pklass=nil
#     cklass=nil
#     sent=false
#     IO.popen("/sbin/tc -s class show dev #{iface}", "r").each do |line|
#       #puts line
#       if (line =~ /class hfsc (\w+):(\w+)/) != nil
#         #puts "pklass = #{$~[1]} cklass =  #{$~[2]}"
#         #next if $~[2].hex < 4
#         pklass = $~[1]
#         cklass = $~[2]
#         sent = true
#       elsif sent and (line =~ /Sent (\d+) /) != nil
#         #puts "sent = #{$~[1]}"
#         karray[pklass] = {} if karray[pklass].nil?
#         karray[pklass][cklass] = 0 if karray[pklass][cklass].nil?
#         karray[pklass][cklass] += $~[1].to_i # if cklass
#         sent = false
#       end
#     end
#     #puts "karray = #{karray.inspect}"
#     karray
#   end

# end

class DaemonCheckBind < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 10.seconds }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_bind }
    super
  end

  def exec_daemon_bind
    system("pgrep -x named || service bind9 start")
  end

end

class DaemonRedis < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 5.seconds }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_redis }
    @factor_precision = 100
    @sample_count = 1.minutes / @time_for_exec[:frecuency] #Cantidad de muestras de redis que contemplan 1.minutes
    super
  end

  def exec_daemon_redis
    begin
      interfaces_to_redis
      contracts_to_redis
    rescue Exception => e
      log_rescue("[#{self.class.name}][#{(__method__).to_s}]", e)
    end
  end

  def interfaces_to_redis
    begin
      @compact_keys = InterfaceSample.compact_keys
      counter_key = "interface_counters"
      transactions = { :create => [], :update => []}
      last_samples = {}
      InterfaceSample.last_sample(0).each { |is| last_samples[is.interface_id.to_s] = is }

      Interface.all.each do |i|
        @relation = i
        @last_db_sample = last_samples[i.id.to_s]
        @redis_key  = "interface_#{i.id}_sample"
        $redis.hset(counter_key, i.id.to_s, 0) unless $redis.hexists(counter_key, i.id.to_s)
        round_robin()
        counter = $redis.hget(counter_key, i.id.to_s)
        catchs = {}
        ["rx", "tx"].each { |prefix| catchs[prefix] = i.send("#{prefix}_bytes") }
        generate_sample(catchs) if i.exist?
        $redis.hincrby(counter_key, i.id.to_s, 1)
        if counter == @sample_count # @sample_count SON LAS MUESTRAS POR MINUTO
          samples = compact_to_db()
          transactions[:create] += samples[:create]
          transactions[:update] += samples[:update]
          $redis.hset(counter_key, i.id_to_s, 0)
        end
      end

      InterfaceSample.transaction{
        transactions[:update].each do |transaction|
          last_samples[transaction[:interface_id].to_s].update_attributes(transaction)
          sample = last_samples[transaction[:contract_id].to_s]
          log("[#{self.class.name}][#{(__method__).to_s}][InterfaceTransactions][#{@relation.class.name}:#{@relation.id}][UPDATE] #{sample.inspect}") if verbose? and not transactions[:create].empty?
        end
        transactions[:create].each do |transaction|
          sample = InterfaceSample.create(transaction)
          log("[#{self.class.name}][#{(__method__).to_s}][InterfaceTransactions][#{@relation.class.name}:#{@relation.id}][CREATE] #{sample.inspect}") if verbose? and not transactions[:create].empty?
        end
      }
    rescue Exception => e
      log_rescue("[#{self.class.name}][#{(__method__).to_s}]", e)
    end
  end

  def data_count(contracts, data_counting)
    Contract.transaction {
      contracts.each do |c|
        unless data_counting[c.id.to_s].nil?
          c.is_connected = data_counting[c.id.to_s].zero? ? false : true
          traffic_current = c.current_traffic || c.create_traffic_for_this_period
          log("[#{self.class.name}][#{(__method__).to_s}][CurrentTraffic][#{c.class.name}:#{c.id}][BEFOREUPDATE] #{traffic_current.data_count} + #{data_counting[c.id.to_s] / 8}") if verbose?
          traffic_current.data_count += data_counting[c.id.to_s] / 8
          c.current_traffic = traffic_current
          c.save
          log("[#{self.class.name}][#{(__method__).to_s}][CurrentTraffic][#{c.class.name}:#{c.id}][UPDATE] #{c.current_traffic.data_count}") if verbose?
        end
      end
    }
  end

  def contracts_to_redis
    begin
      transactions = { :create => [], :update => [] }
      data_counting = {}
      last_samples = {}
      @compact_keys = ContractSample.compact_keys
      counter_key = "contract_counters"
      hfsc_class = { "up" => `/sbin/tc -s class show dev #{SequreispConfig::CONFIG["ifb_up"]}`.split("\n\n"),
                     "down" => `/sbin/tc -s class show dev #{SequreispConfig::CONFIG["ifb_down"]}`.split("\n\n") }

      ContractSample.last_sample(0).each { |cs| last_samples[cs.contract_id.to_s] = cs }
      contracts = Contract.all(:include => :current_traffic)
      contracts.each do |c|
        @relation = c
        @last_db_sample = last_samples[c.id.to_s]
        @redis_key  = "contract_#{c.id}_sample"
        $redis.hset(counter_key, c.id.to_s, 0) unless $redis.hexists(counter_key, c.id.to_s)
        round_robin()
        catchs = {}
        @compact_keys.each do |rkey|
          tc_class = c.send("tc_#{rkey[:sample]}")
          classid = "#{tc_class[:qdisc]}:#{tc_class[:mark]}"
          parent  = "#{tc_class[:qdisc]}:#{tc_class[:parent]}"
          contract_class = hfsc_class[rkey[:up_or_down]].select{|k| k.include?("class hfsc #{classid} parent #{parent}")}.first
          catchs["#{rkey[:name]}"] = contract_class.split("\n").select{|k| k.include?("Sent ")}.first.split(" ")[1]
        end
        counter = $redis.hget(counter_key, c.id.to_s).to_i
        generate_sample(catchs)
        $redis.hincrby(counter_key, c.id.to_s, 1)
        if counter == @sample_count # @sample_count SON LAS MUESTRAS POR MINUTO
          samples = compact_to_db()
          transactions[:create] += samples[:create]
          transactions[:update] += samples[:update]
          data_counting[c.id.to_s] = samples[:total]
          $redis.hset(counter_key, c.id.to_s, 0)
        end
      end

      data_count(contracts, data_counting)

      ContractSample.transaction {
        transactions[:update].each do |transaction|
          last_samples[transaction[:contract_id].to_s].update_attributes(transaction)
          sample = last_samples[transaction[:contract_id].to_s]
          log("[#{self.class.name}][#{(__method__).to_s}][ContractTransactions][#{@relation.class.name}:#{@relation.id}][UPDATE] #{sample.inspect}") if verbose? and not transactions[:update].empty?
        end
        transactions[:create].each do |transaction|
          sample = ContractSample.create(transaction)
          log("[#{self.class.name}][#{(__method__).to_s}][ContractTransactions][#{@relation.class.name}:#{@relation.id}][CREATE] #{sample.inspect}") if verbose? and not transactions[:create].empty?
        end
      }
    rescue Exception => e
      log_rescue("[#{self.class.name}][#{(__method__).to_s}]", e)
    end
  end

  def round_robin
    date_keys =$redis.keys("#{@redis_key}_*").sort
    $redis.del(date_keys.first) if date_keys.count == @sample_count
  end

  def generate_sample(catchs)
    begin
      new_sample = { :time => (DateTime.now.to_f * @factor_precision).to_i }
      new_key = "#{@redis_key}_#{new_sample[:time]}"
      last_key = $redis.keys("#{@redis_key}_*").sort.last

      catchs.each_key do |sub_key|
        new_sample[sub_key] = {}
        # total_bytes, last_accumulated, last_time = $redis.hmget("#{last_key}", "#{sub_key}_total_bytes", "#{sub_key}_accumulated", "time") unless last_key.nil?
        total_bytes, last_time = $redis.hmget("#{last_key}", "#{sub_key}_total_bytes", "time") unless last_key.nil?
        accumulated = (catchs[sub_key].to_i < total_bytes.to_i ? total_bytes.to_i : (catchs[sub_key].to_i - total_bytes.to_i) ) unless last_key.nil?
        new_sample[sub_key][:instant] = last_key.nil? ? "0" : (((accumulated * @factor_precision) / (new_sample[:time] - last_time.to_i)) * 8)
        #new_sample[sub_key][:accumulated] = last_key.nil? ? "0" : (last_accumulated.to_i + accumulated)
        new_sample[sub_key][:total_bytes] = catchs[sub_key].to_i
      end
      catchs.each_key { |k| new_sample[k].each_key { |sub_key| $redis.hmset("#{new_key}", "#{k}_#{sub_key}", new_sample[k][sub_key]) } }
      $redis.hmset("#{new_key}", "time", new_sample[:time])
    rescue Exception => e
      log_rescue("[#{self.class.name}][#{(__method__).to_s}]", e)
    end
  end

  def compact_to_db
    begin
      samples = { :create => [], :update => [], :total => 0 }
      data = {}
      time_period = 60
      period = 0
      # ME TRAIGO TODAS LAS KEYS DE REDIS ORDENAS.
      date_keys = $redis.keys("#{@redis_key}_*").sort

      date_keys.each do |key|
        time = $redis.hget("#{key}", "time")
        data[time] = {}
        @compact_keys.each { |rkey| data[time][rkey[:name]] = $redis.hget("#{key}", "#{rkey[:name]}_instant").to_i }
      end

      time_samples = data.keys.map(&:to_i).sort

      if verbose?
        time_samples.each do |key|
          log("[#{self.class.name}][#{(__method__).to_s}][SamplesTimesRedis][#{@relation.class.name}:#{@relation.id}] #{key} (#{Time.at(key / @factor_precision)}) ---> #{data[key.to_s].inspect}")
        end
      end

      #DIVIDO POR EL FACTOR PRECISION PARA OBTENER LA HORA POSTA PERO EN ENTERO.
      # CHEQUEO QUE EN EL UTIMO SAMPLE DE UN MINUTO QUE TENGO, SI HAY ALGUN SAMPLE DE REDIS QUE DEBA METER PARA ACTUALIZAR ESA MUESTRA.
      unless @last_db_sample.nil?
        init_time_last_sample = @last_db_sample.sample_number.to_i
        end_time_last_sample  = init_time_last_sample + ((time_period*@factor_precision)-1)
        range = (init_time_last_sample..(end_time_last_sample))
        dates_selected = time_samples.select{|k| range.include?(k.to_i)}
        log("[#{self.class.name}][#{(__method__).to_s}][LastSample][Range] (#{init_time_last_sample} - #{end_time_last_sample}) ---> #{Time.at(init_time_last_sample / @factor_precision)} - #{Time.at(end_time_last_sample / @factor_precision)}") if verbose?
        unless dates_selected.empty?
          new_sample = {"#{@relation.class.name.downcase}_id".to_sym => @relation.id}
          @compact_keys.each { |rkey| new_sample[rkey[:name].to_sym] = @last_db_sample[rkey[:name].to_sym] }
          log("[#{self.class.name}][#{(__method__).to_s}][LastSample][#{@relation.class.name}:#{@relation.id}] #{@last_db_sample.inspect}") if verbose?
          dates_selected.each do |date|
            log("[#{self.class.name}][#{(__method__).to_s}][LastSample][DataSelect][#{@relation.class.name}:#{@relation.id}] (#{date}) ---> #{Time.at(date / @factor_precision)}") if verbose?
            @compact_keys.each do |rkey|
              samples[:total] += data[date.to_s][rkey[:name]]
              new_sample[rkey[:name].to_sym] += data[date.to_s][rkey[:name]]
            end
          end
          samples[:update] << new_sample
        end
      end

      init_time_new_sample = @last_db_sample.nil? ? (Time.at(time_samples.first / @factor_precision).change(:sec => 0).to_f * @factor_precision).to_i : @last_db_sample.sample_number.to_i + (time_period * @factor_precision)

      i = 0
      while init_time_new_sample < time_samples.last
        end_time_new_sample  = init_time_new_sample + ((time_period*@factor_precision)-1)
        range = (init_time_new_sample..end_time_new_sample)
        log("[#{self.class.name}][#{(__method__).to_s}][NewSample][Range][#{@relation.class.name}:#{@relation.id}] (#{init_time_new_sample} - #{end_time_new_sample}) ---> #{Time.at(init_time_new_sample / @factor_precision)} - #{Time.at(end_time_new_sample / @factor_precision)}") if verbose?
        sample_time = Time.at(init_time_new_sample.to_f / @factor_precision).change(:sec => 0)
        new_sample = {:period => period, :sample_time => sample_time, :sample_number => init_time_new_sample.to_s, "#{@relation.class.name.downcase}_id".to_sym => @relation.id }
        @compact_keys.each { |rkey| new_sample[rkey[:name].to_sym] = 0 }
        time_samples.select{|k| range.include?(k)}.each do |date|
          log("[#{self.class.name}][#{(__method__).to_s}][NewSample][DataSelect][#{@relation.class.name}:#{@relation.id}] (#{date}) ---> #{Time.at(date / @factor_precision)}") if verbose?
          @compact_keys.each do |rkey|
            samples[:total] += data[date.to_s][rkey[:name]]
            new_sample[rkey[:name].to_sym] += data[date.to_s][rkey[:name]]
          end
        end
        samples[:create] << new_sample
        i += 1
        init_time_new_sample = init_time_new_sample + (i*time_period*@factor_precision)
      end
      samples
    rescue Exception => e
      log_rescue("[#{self.class.name}][#{(__method__).to_s}]", e)
    end
  end
end

class DaemonCompactSamples < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 20.seconds }
    @wait_for_apply_changes = true
    @factor_precision = 100
    @proc = Proc.new { exec_daemon_compact_samples }
    super
  end

  def exec_daemon_compact_samples
    begin
      models_to_compact.each do |model|
        @klass = "#{model}_sample".camelize.constantize
        transactions = { :create => [], :destroy => [] }
        @sample_conf = @klass.sample_conf
        (@sample_conf.count - 1).times do |i|
          @sample_conf["period_#{i}".to_sym][:samples].each_key do |c_id|
            sample = @sample_conf["period_#{i}".to_sym][:samples][c_id]
            @relation = sample.object #ESTA EN UN INCLUDE NO CUESTA NADA TRAERLO
            excess = @sample_conf["period_#{i}".to_sym][:sample_size_cut]
            if sample.total_samples.to_i >= excess
              log("[#{self.class.name}][#{(__method__).to_s}][NeedCompact] (#{@klass.name} => #{@relation.id}) #{sample.total_samples} > #{excess}") if verbose?
              last_sample_period = @sample_conf["period_#{i.next}".to_sym][:samples][c_id]
              data = @sample_conf["period_#{i}".to_sym][:excess_samples][@relation.id.to_s]
              samples = compact(i.next, data, last_sample_period)
              @sample_conf["period_#{i.next}".to_sym][:samples][c_id].total_samples = (@sample_conf["period_#{i.next}".to_sym][:samples][c_id].total_samples.to_i + samples[:create].size) unless @sample_conf["period_#{i.next}".to_sym][:samples][c_id].nil?
              transactions[:create] += samples[:create]
              transactions[:destroy] += samples[:destroy]
            end
          end
        end
        @klass.transaction {
          transactions[:destroy].each do |transaction|
            log("[#{self.class.name}][#{(__method__).to_s}][#{@klass.name}Transactions][#{@relation.class.name}:#{@relation.id}][DESTROY] #{transaction.inspect}") if (verbose? and not transactions[:destroy].empty?)
            transaction.delete
          end
          transactions[:create].each do |transaction|
            sample = @klass.create(transaction)
            @sample_conf["period_#{transaction[:period]}".to_sym][:samples][transaction[:contract_id]] = sample
            log("[#{self.class.name}][#{(__method__).to_s}][#{@klass.name}Transactions][#{@relation.class.name}:#{@relation.id}][CREATE] #{sample.inspect}") if (verbose? and not transactions[:create].empty?)
          end
        }
      end
    rescue Exception => e
      log_rescue("[#{self.class.name}][#{(__method__).to_s}]", e)
    end
  end

  private

  def models_to_compact
    ["contract"]
  end

  def compact(period, data, last_sample_period=nil)
    begin
      samples = { :create => [], :destroy => [] }
      time_period = (60 * @sample_conf["period_#{period}".to_sym][:time_sample])
      time_samples = data.collect(&:sample_number).map(&:to_i).sort
      init_time_new_sample = last_sample_period.nil? ? time_samples.first : (last_sample_period.sample_number.to_i + (time_period * @factor_precision))
      end_time_new_sample = init_time_new_sample + ((time_period*@factor_precision)-1)
      range = (init_time_new_sample..end_time_new_sample)
      sample_time = Time.at(init_time_new_sample.to_f / @factor_precision).change(:sec => 0)
      log("[#{self.class.name}][#{(__method__).to_s}][Range] (#{init_time_new_sample} - #{end_time_new_sample}) ---> #{Time.at(init_time_new_sample / @factor_precision)} - #{Time.at(end_time_new_sample / @factor_precision)}") if verbose?
      data.each do |k|
        if range.include?(k.sample_number.to_i)
          samples[:destroy] << k
          log("[#{self.class.name}][#{(__method__).to_s}][DataSelected][#{@relation.class.name}:#{@relation.id}][Compact] (#{@klass.name} => #{@relation.id}) #{k.sample_number} --> #{k.inspect}") if verbose?
        else
          log("[#{self.class.name}][#{(__method__).to_s}][DataSelected][#{@relation.class.name}:#{@relation.id}][NoCompact] (#{@klass.name} => #{@relation.id}) #{k.sample_number} --> #{k.inspect}") if verbose?
        end
      end
      new_sample = @klass.compact(samples[:destroy])
      samples[:create] << new_sample.merge({:period => period, :sample_time => sample_time, :sample_number => init_time_new_sample.to_s, "#{@relation.class.name.downcase}_id".to_sym => @relation.id })
      samples
    rescue Exception => e
      log_rescue("[#{self.class.name}][#{(__method__).to_s}]", e)
    end
  end
end

class DaemonSynchronizeTime < DaemonTask
  def initialize
    @time_for_exec = { :frecuency => 1.day }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_sync_time }
    super
  end

  def exec_daemon_sync_time
    commands = ["ntpdate pool.ntp.org", "hwclock --systohc"].each do |command|
      command_output = `#{command}`
      log "#{self.class.name}][#{(__method__).to_s}] command: #{command}, output: #{command_output}, exit_status: #{$?.exitstatus}" if verbose?
    end
  end
end

#########################################################
#
#
#########################################################
