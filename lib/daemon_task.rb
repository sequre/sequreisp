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

class DaemonDataCounting < DaemonTask

  def initialize
    @time_for_exec = { :frecuency => 60.seconds }
    @max_current_traffic_count = 1000 / 8 * 1024 * 1024 * 60
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_data_counting }
    super
  end

  def exec_daemon_data_counting
    exec_data_counting
  end

  def exec_data_counting
    hash_count = { "up" => {}, "down" => {} }
    contracts = Contract.not_disabled(:include => :current_traffic)
    contract_count = contracts.count
    parse_data_count(contracts, hash_count)

    ActiveRecord::Base.transaction do
      begin
        File.open(File.join(DEPLOY_DIR, "log/data_counting.log"), "a") do |f|
          contracts.each do |c|
            traffic_current = c.current_traffic || c.create_traffic_for_this_period
            c.is_connected = false

            Configuration::COUNT_CATEGORIES.each do |category|
              data_total = 0
              data_total += hash_count["up"][c.ip][category].to_i if hash_count["up"].has_key?(c.ip)
              data_total += hash_count["down"][c.ip][category].to_i if hash_count["down"].has_key?(c.ip)

              if data_total != 0
                c.is_connected = true
                current_traffic_count = traffic_current.data_count
                eval("traffic_current.#{category} += data_total") if data_total <= @max_current_traffic_count

                #Log data counting
                # if contract_count <= 300 and Rails.env.production?
                #   if (data_total >= 7864320) or (eval("c.current_traffic.#{category} - current_traffic_count >= 7864320")) or (eval("(c.current_traffic.#{category} - data_total) != current_traffic_count"))
                #     f.puts "#{Time.now.strftime('%d/%m/%Y %H:%M:%S')}, ip: #{c.ip}(#{c.current_traffic.id}), Category: #{category}, Data Count: #{tmp},  Data readed: #{hash_count[c.ip]}, Data Accumulated: #{c.current_traffic.data_count}"
                #   end
                # end
                traffic_current.save if traffic_current.changed?
              end
            end

            c.save if c.changed?
          end
        end
      rescue => e
        log_rescue("[Daemon] ERROR Thread #{name}", e)
        # Rails.logger.error "ERROR TrafficDaemonThread: #{e.inspect}"
      ensure
        time_last = Time.now
        system "iptables -t filter -Z" if Rails.env.production?
      end
    end
  end

  def parse_data_count(contracts, hash_count)
    if SequreispConfig::CONFIG["demo"]
      contracts.all.each do |contract|
        hash_count["up"][contract.ip]["data_count"] = rand(1844674)
        hash_count["down"][contract.ip]["data_count"] = rand(1844674)
      end
    else
      begin
        # [["bytes", "ip", "up|down", "data_count"], ["bytes", "ip", "up|down", "data_count"]]
        File.read("|iptables-save -t filter -c").scan(/\[.*:(\d+)\].*comment \"data-count-(.*)-(.*)-(.*)\"/).each do |line|
          # line[0] => byte's, line[1] => i1p, line[2] => up | down, line[3] => category, where the category name is the same with  any traffic attribute
          if line[0] != "0"
            hash_count[line[2]][line[1]] = {}
            hash_count[line[2]][line[1]][line[3]] = line[0]
          end
        end
      rescue => e
        log_rescue("[Daemon] ERROR Thread #{name}", e)
      end
    end
  end

end


class DaemonRrdFeed < DaemonTask

  require 'rrd'
  #require 'ruby-debug'
  # IFB_UP="ifb0"
  # IFB_DOWN="ifb1"
  RRD_DIR=RAILS_ROOT + "/db/rrd"
  INTERVAL=300

  def initialize
    @time_for_exec = { :frecuency => 5.minutes }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_rrd_feed unless Configuration.in_safe_mode? }
    super
  end

  def exec_daemon_rrd_feed
    exec_rrd_feed
  end

  def exec_rrd_feed
    client_up = tc_class(IFB_UP)
    client_down = tc_class(IFB_DOWN)
    time_c = Time.now

    # if Configuration.use_global_prios
    #   p_up, p_down = {}, {}
    #   Interface.all(:conditions => { :kind => "lan" }).each do |i|
    #     p_down = tc_class i.name, p_down
    #   end
    #   Provider.enabled.all.each do |p|
    #     p_up = tc_class p.link_interface, p_up
    #   end
    # else
    p_up, p_down = [], []
    Provider.enabled.all.each do |p|
      p_up[p.id] = File.open("/sys/class/net/#{p.interface.name}/statistics/tx_bytes").read.chomp.to_i rescue 0
      p_down[p.id] = File.open("/sys/class/net/#{p.interface.name}/statistics/rx_bytes").read.chomp.to_i rescue 0
    end
    # end
    time_p = Time.now

    i_up, i_down = [], []
    Interface.all.each do |i|
      i_up[i.id] = File.open("/sys/class/net/#{i.name}/statistics/tx_bytes").read.chomp rescue 0
      i_down[i.id] = File.open("/sys/class/net/#{i.name}/statistics/rx_bytes").read.chomp rescue 0
    end
    time_i = Time.now

    # SECOND we made the updates
    Contract.all.each do |c|
      # if Configuration.use_global_prios
      #   rrd_update c, time_c, client_down["1"][c.class_hex], 0, client_up["1"][c.class_hex], 0
      # else
      rrd_update c, time_c, client_down["1"][c.class_prio2_hex], client_down["1"][c.class_prio3_hex], client_up["1"][c.class_prio2_hex], client_up["1"][c.class_prio3_hex]
      # end
    end

    ProviderGroup.enabled.each do |pg|
      pg_down_prio2 = pg_down_prio3 = pg_up_prio2 = pg_up_prio3 = 0
      pg.providers.enabled.each do |p|
        p_down_prio2 = p_down_prio3 = p_up_prio2 = p_up_prio3 = 0
        # if Configuration.use_global_prios
        #   p_down_prio2 = p_down[p.class_hex]["a"] + p_down[p.class_hex]["b"] rescue 0
        #   p_down_prio3 = p_down[p.class_hex]["c"] rescue 0
        #   # dynamic ifaces like ppp could not exists, so we need to rescue an integer
        #   # if we scope providers by ready and online, we may skip traffic to be logged
        #   # and the ppp iface could go down betwen check and the read
        #   p_up_prio2 = (p_up[p.class_hex]["a"] + p_up[p.class_hex]["b"]) rescue 0
        #   p_up_prio3 = p_up[p.class_hex]["c"] rescue 0
        # else
        p_up_prio2 = p_up[p.id]
        p_down_prio2 = p_down[p.id]
        # end
        rrd_update p, time_p, p_down_prio2, p_down_prio3, p_up_prio2, p_up_prio3
        pg_down_prio2 += p_down_prio2
        pg_down_prio3 += p_down_prio3
        pg_up_prio2 += p_up_prio2
        pg_up_prio3 += p_up_prio3
      end
      rrd_update pg, time_p, pg_down_prio2, pg_down_prio3, pg_up_prio2, pg_up_prio3
    end

    Interface.all.each do |i|
      rrd_update i, time_i, i_down[i.id], 0, i_up[i.id], 0
    end
  end

  def rrd_create(path, time)
    RRD::Wrapper.create '--start', (time - 60.seconds).strftime("%s"), path,
    "-s", "#{INTERVAL.to_s}",
    # max = 1*1024*1024*1024*600 = 1Gbit/s * 600s
    "DS:down_prio:DERIVE:600:0:644245094400",
    "DS:down_dfl:DERIVE:600:0:644245094400",
    "DS:up_prio:DERIVE:600:0:644245094400",
    "DS:up_dfl:DERIVE:600:0:644245094400",
    #(24x60x60/300)*30dias
    "RRA:AVERAGE:0.5:1:8640",
    #(24x60x60x30/300)*12meses
    "RRA:AVERAGE:0.5:30:3456",
    #(24x60x60x30x12/300)*10años
    "RRA:AVERAGE:0.5:360:2880"
  end

  def rrd_update(o, time, down_prio, down_dfl, up_prio, up_dfl)
    log("[Daemon][RRD][rrd_update] o=#{o.name}, time=#{time}, down_prio=#{down_prio}, down_dfl=#{down_dfl}, up_prio=#{up_prio}, up_dfl=#{up_dfl}") if verbose?
    rrd_path = RRD_DIR + "/#{o.class.name}.#{o.id.to_s}.rrd"
    rrd_create(rrd_path, time) unless File.exists?(rrd_path)
    RRD::Wrapper.update rrd_path, "-t", "down_prio:down_dfl:up_prio:up_dfl", "#{time.strftime("%s")}:#{down_prio}:#{down_dfl}:#{up_prio}:#{up_dfl}"
    #puts "#{o.klass.number.to_s(16) rescue nil} #{rrd_path} #{time.strftime("%s")}:#{down_prio}:#{down_dfl}:#{up_prio}:#{up_dfl}"
  end

  def tc_class(iface, karray = {})
    pklass=nil
    cklass=nil
    sent=false
    IO.popen("/sbin/tc -s class show dev #{iface}", "r").each do |line|
      #puts line
      if (line =~ /class hfsc (\w+):(\w+)/) != nil
        #puts "pklass = #{$~[1]} cklass =  #{$~[2]}"
        #next if $~[2].hex < 4
        pklass = $~[1]
        cklass = $~[2]
        sent = true
      elsif sent and (line =~ /Sent (\d+) /) != nil
        #puts "sent = #{$~[1]}"
        karray[pklass] = {} if karray[pklass].nil?
        karray[pklass][cklass] = 0 if karray[pklass][cklass].nil?
        karray[pklass][cklass] += $~[1].to_i # if cklass
        sent = false
      end
    end
    #puts "karray = #{karray.inspect}"
    karray
  end

end

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
  end

  def exec_daemon_redis
    # Interface.all.each do |i|
    #   $redis.set("interface:#{i.id}:counter", 0) unless $redis.exists("interface:#{i.id}:counter")
    #   counter = $redis.get("interface:#{i.id}:counter")
    #   ["rx", "tx"].each do |prefix|
    #     generate_sample("interface:#{i.name}:rate_#{prefix}", "interface:#{i.id}:#{counter}", i.send("#{prefix}_bytes")) if i.exist?
    #   end
    #   $redis.incr("interface:#{i.id}:counter")
    # end
    hfsc_class = { "up" => `/sbin/tc -s class show dev #{SequreispConfig::CONFIG["ifb_up"]}`.split("\n\n"),
                   "down" => `/sbin/tc -s class show dev #{SequreispConfig::CONFIG["ifb_down"]}`.split("\n\n") }

    $redis_mutex.synchronize {
      Contract.all.each do |c|
        $redis.set("contract:#{c.id}:counter", 0) unless $redis.exists("contract:#{c.id}:counter")
        counter = $redis.get("contract:#{c.id}:counter").to_i
        catchs = {}
        c.redis_keys.each do |rkey|
          tc_class = c.send("tc_#{rkey[:sample]}")
          classid = "#{tc_class[:qdisc]}:#{tc_class[:mark]}"
          parent  = "#{tc_class[:qdisc]}:#{tc_class[:parent]}"
          contract_class = hfsc_class[rkey[:up_or_down]].select{ |k| k.include?("class hfsc #{classid} parent #{parent}")}.first
          catchs["#{rkey[:name]}"] = contract_class.split("\n").select{ |k| k.include?("Sent ")}.first.split(" ")[1]
        end
        generate_sample("contract:#{c.id}:sample", counter, catchs)
        $redis.incr("contract:#{c.id}:counter")
      end
    }
  end

  # key: "object_name:object:id:nuevas_muestras_tc"
  # id: numero de la nueva muestra. Comienza en cero.
  # catchs = { "[up|down]:[prio1|prio2|prio3|supercache]" => bytes_leidos_de_tc }
  def generate_sample(key, id, catchs)
    new_sample = { :time => (DateTime.now.to_f * @factor_precision).to_i }

    catchs.each_key do |sub_key|
      new_sample[sub_key] = {}
      total_bytes, last_accumulated, last_time = $redis.hmget("#{key}:#{id-1}", "#{sub_key}:total_bytes", "#{sub_key}:accumulated", "time") unless id.zero?
      accumulated = (catchs[sub_key].to_i - total_bytes.to_i) unless id.zero?
      new_sample[sub_key][:instant] = id.zero? ? "0" : (((accumulated * @factor_precision) / (new_sample[:time] - last_time.to_i)) * 8)
      new_sample[sub_key][:accumulated] = id.zero? ? "0" : (last_accumulated.to_i + accumulated)
      new_sample[sub_key][:total_bytes] = catchs[sub_key].to_i
    end

    catchs.each_key do |k|
      new_sample[k].each_key { |sub_key| $redis.hmset("#{key}:#{id}", "#{k}:#{sub_key}", new_sample[k][sub_key]) }
    end
    $redis.hmset("#{key}:#{id}", "time", new_sample[:time])
  end

end

class DaemonCompactSamples < DaemonTask
  # PERIOD   AMPLITUD              TIME_SAMPLE           SAMPLES_SIZE   SAMPLES_SIZE_SATURA
  # 0        180.min (3.hours)        1.min              300            300 + 5 = 305
  # 1        1440.min (1.day)         5.min              288            288 + 6 = 294
  # 2        10080.min (1.week)      30.min              336            336 + 6 = 342
  # 3        44640.min (1.month)    180.min (3.hours)    348            348 + 8 = 356
  # 4        525600.min (1.year)   1440.min (24.hours)   365            365
  def initialize
    @time_for_exec = { :frecuency => 1.minutes }
    @wait_for_apply_changes = true
    @proc = Proc.new { exec_daemon_compact_samples }
    @sample_conf = { :period_0 => { :period_number => 0, :time_sample => 1,    :sample_size => 300, :sample_size_cut => 305, :excess_count => 5,   :scope => 180.minutes },
                     :period_1 => { :period_number => 1, :time_sample => 5,    :sample_size => 288, :sample_size_cut => 294, :excess_count => 6,   :scope => 1440.minutes },
                     :period_2 => { :period_number => 2, :time_sample => 30,   :sample_size => 336, :sample_size_cut => 342, :excess_count => 6,   :scope => 10080.minutes },
                     :period_3 => { :period_number => 3, :time_sample => 180,  :sample_size => 348, :sample_size_cut => 356, :excess_count => 8,   :scope => 44640.minutes },
                     :period_4 => { :period_number => 4, :time_sample => 1440, :sample_size => 348, :sample_size_cut => nil, :excess_count => nil, :scope => 525600.minutes }
                   }
    super
  end

  def exec_daemon_compact_samples
    transactions = []
    #POR CADA EJECUCION DEL DAEMON NECESITO TRAERME EL VALOR ACTUALIZADO DE CUANTOS SAMPLES HAY POR CONTRATO EN CADA UNO DE LOS PERIODOS.
    @sample_conf.each_key { |key| @sample_conf[key][:samples] = ContractSample.total_for_period(@sample_conf[key][:period_number]) }

    Contract.all.each do |c|
      #NECESITO QUE ESTO SEA ATOMICO; QUE HAGA TODO ANTES DE QUE SE EJECUTE REDIS.
      $redis_mutex.synchronize { samples = redis_compact(c) }
      unless samples.empty?
        transactions << samples[:create] + samples[:update]
        # Me traigo la cantidad de samples del periodo 0 en la base de datos.
        total_samples = @samples_conf[:period_0][:samples].select{|cs| cs.id == c.id}.first.total_samples
        flag = ((total_samples + samples.count) >= @sample_conf[:period_0][:sample_size_cut]) ? true : false
        compact_count = (total_samples + samples.count) - @sample_conf[:period_0][:sample_size]
        # PROCESO ITERATIVO DE COMPACTACIÓN: con el upto evito el periodo 0 que es el de un minuto, que ya compate arriba (REDIS)
        1.upto(@samples_conf.keys.count-1) do |per|
          # SI flag ES FALSE NO PUEDO COMPACTAR EL PERIODO, POR LO QUE IMPLICA QUE TAMPOCO VOY A PODER COMPACTAR LOS SUBSIGUIENTES.
          break if not flag
          flag = false
          total_samples = @samples_conf["period_#{per}".to_sym][:samples].select{|cs| cs.id == c.id}.first.total_samples
          samples = compact(per, compact_count, c)
          transactions << samples[:create] + samples[:destroy]
          compact_count = (total_samples + samples[:create].count) - @samples_conf["period_#{per}".to_sym][:sample_size]
          flag = ((total_samples + samples[:create].count) >= @samples_conf["period_#{per}".to_sym][:sample_size_cut]) ? true : false
        end
      end
    end
    ContractSample.transaction{ transactions.flatten.each {|s| eval(s)} } unless transactions.empty?
  end

  def redis_compact(c)
    samples = { :create => [], :update => [] }
    if $redis.exists("contract:#{c.id}:counter")
      # data = { "time" => { "[prio1|prio2|prio3|supercache]:[up|down]" => instant } }
      data = {}
      #Cantidad de registros en redis para el contrato.
      counter = $redis.get("contract:#{c.id}:counter").to_i
      # Considero el counter nil, si por casualidad se llegara a ejecutar primero este daemon antes que el de redis, quien create el registro counter.
      # 12 son las cantidad de muestas de 5 segundos que tomo de redis, ya que en teoria esas 12 muestras contemplarian el nuevo minuto.
      if not counter.nil? and counter >= 12
        #Me traigo la muestra mas reciente de un minuto que tenga este contrato en la base de datos.
        last_sample = ContractSample.all( :conditions => { :contract_id => c.id, :period => 0 }).last
        ######## TO-DO: NECESITO QUE ESTE COUNTER TIMES SEA ATOMICO, NO PUEDE PERMITIR QUE SE CORTE Y SE EJECUTE EL DAEMON DE REDIS
        counter.times do |x|
          time = $redis.hmget("contract:#{c.id}:sample:#{x}", "time")
          data[time] = {}
          c.redis_keys.each do |rkey|
            data[time][rkey[:name]] = $redis.hmget("contract:#{c.id}:sample:#{x}", "#{rkey[:name]}:instant").first.to_i
            $redis.del("contract:#{c.id}:sample:#{x}")
          end
        end
        $redis.set("contract:#{c.id}:counter", 0)

        time_last_sample = last_sample.nil? ? dates_selected.first : last_sample.period_time.to_i
        unless last_sample.nil?
          # ME TRAIGO TODAS LAS FECHAS ORDENAS DE LAS MUESTRAS.
          dates = data.keys.map(&:to_i).sort

          # Caso de que una de las muestras matche con la ultima que tenga y deba actualizarlo.
          range = (time_last_sample..(time_last_sample + (time_period - 1)))
          dates_selected = dates.select{|k| range.include?(k)}

          unless dates_selected.empty?
            dates_selected.each { |date| c.redis_keys.each { |rkey| last_sample[rkey[:name].to_sym] += data[date.to_s][rkey[:name]] } }
            samples[:update] << "#{last_sample.save}"
          end
        end

        samples = create_samples(time_last_sample, data, @sample_conf[:period_0][:time_sample]*60, @sample_conf[:period_0][:period_number], c) #Genero los samples de 1 minuto
      end
    end
    samples
  end

  # period => periodo al que voy a compactar las samples, :compact_count => cantidad de muestras que debo compactar, c => contrato.
  def compact(period, compact_count, c)
    data = {}
    samples = { :create => [], :destroy => [], :update => [] }
    last_sample_period = ContractSample.all( :conditions => { :contract_id => c.id, :period => period } ).last
    samples_to_compact = ContractSample.all( :conditions => { :contract_id => c.id, :period => (period-1) }, :order => "created_at DESC", :limit => compact_count )
    samples_to_compact.each do |x|
      time = samples_to_compact.period_time.to_i
      data[time] = {}
      c.redis_keys.each do |rkey|
        data[time][rkey[:name]] = x.send(rkey[:name])
        samples[:destroy] << "#{x.destroy}"
      end
    end
    time_last_sample = last_sample.nil? ? data.keys.map(&:to_i).sort.first : last_sample.period_time.to_i
    samples[:create] = create_samples(time_last_sample, data, @sample_conf["period_#{period}"][:time_sample]*60, period, c)
    samples
  end

  def create_samples(last_sample, new_data, time_period, period, c)
    samples = []
    time_last_sample = last_sample.period_time.to_i
    # ME TRAIGO TODAS LAS FECHAS ORDENAS DE LAS MUESTRAS.
    dates = new_data.keys.map(&:to_i).sort
    # ESTO ME DA LA CANTIDAD DE SLOTS QUE NECESITO DE UN X MINUTES EN FUNCION DE LAS MUESTRAS QUE TENGO.
    # el count_slots es la cantidad de nuevos slots que debo crear, pero tengo que contemplar un caso mas cuando son samples desde redis, ya que es posible que deba actualizar el ultimo sample de un minuto
    count_slots = (dates.last - time_last_sample) / time_period

    # count_slots.times do |i|
    1.upto(count_slots) do |i|
      # ESTE EL EL RANGO DEL NUEVO SAMPLE i
      new_sample = {:period => period, :period_time => Time.at((time_last_sample + i*time_period)), :contract_id => c.id }
      # new_sample = { :down_prio1 => 0, :down_prio2 => 0, :down_prio3 => 0, :down_supercache => 0, :up_prio1 => 0, :up_prio2 => 0, :up_prio3 => 0 }
      c.redis_keys.each { |rkey| new_sample["#{rkey[:up_or_down]}_#{rkey[:sample]}".to_sym] = 0 }
      range = ((time_last_sample + i*time_period)..(time_last_sample + ((i+1)*time_period) - 1))
      dates_selected = dates.select{|k| range.include?(k)}
      dates_selected.each { |date| c.redis_keys.each { |rkey| new_sample[rkey[:name].to_sym] += new_data[date.to_s][rkey[:name]] } }
      samples << "#{ContractSample.new(new_sample)}"
    end
    samples
  end

end

#########################################################
#
#
#########################################################
