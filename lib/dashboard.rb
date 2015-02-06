module Dashboard
  class Service
    SERVICES= [
      { :id => 1,:name => I18n.t("dashboard.name_service.sequreisp_daemon"), :command => 'ruby' , :pattern => 'sequreispd.rb ' },
      { :id => 2,:name => I18n.t("dashboard.name_service.bind_dns_server"), :command => 'named', :pattern => 'named'},
      { :id => 3,:name => I18n.t("dashboard.name_service.apache_web_server"), :command => 'apache2', :pattern => 'apache2' },
      { :id => 4,:name => I18n.t("dashboard.name_service.mysql_server"), :command => 'mysqld', :pattern => 'mysqld' }
    ]

    SERVICES << { :id => 99,:name => 'SSH Server', :command => 'sshd', :pattern => 'sshd' } if Rails.env.development?

    attr_reader :name, :mem_p, :cpu_p, :mem, :up, :id, :mem_p_html, :cpu_p_html, :up_html
    def initialize(service)
       # SPACE at the END DOES MATTER
      pids = `pgrep -f '#{service[:pattern]}'`.split
      @mem_p = @cpu_p = @mem = 0.0
      @up = false
      pids.each do |pid|
        command, pcpu, pmem, rss = `ps --no-headers -o comm,pcpu,pmem,rss --pid #{pid}`.split
        if command == service[:command]
          @up = true
          @mem_p += pmem.to_f
          @cpu_p += pcpu.to_f
          @mem += rss.to_i
        end
      end
      @id = service[:id]
      @mem_p = @mem_p.round(2)
      @cpu_p = @cpu_p.round(2)
      @mem /= 1024
      @name = service[:name]

      color = (mem_p > 60 or not up) ? '#ff0000' : '#00aa00'
      @mem_p_html = "<span style=\"color: #{color}\">#{mem_p} (#{mem.round}MB)</span>"

      color = (cpu_p > 60 or not up) ? '#ff0000' : '#00aa00'
      @cpu_p_html = "<span style=\"color: #{color}\">#{cpu_p}</span>"

      color = up ? '#00aa00' : '#ff0000'
      word = up ? "UP" : "DOWN"
      @up_html = "<span style=\"color: #{color}\">#{word}</span>"
    end
    def stats
    end
    def self.load_all
      servs = SERVICES
      servs.each_with_object([]) do |s,memo|
        memo << Service.new(s)
      end
    end
  end

  class Daemon
    attr_reader :id, :name, :status, :error, :status_html

    def initialize(daemon)
      @id = daemon[:id]
      @name = daemon[:name].humanize
      @status = daemon[:status]

      color = @status ? '#00aa00' : '#ff0000'
      word = @status ? "UP" : "DOWN"
      @status_html = "<span style=\"color: #{color}\">#{word}</span>"
    end

    def self.load_all
      id = 1
      daemons = []
      Configuration.daemons.each do |daemon|
        _daemon = {}
        _daemon[:id] = id
        _daemon[:name] = daemon
        _daemon[:status] = File.zero?("#{DEPLOY_DIR}/tmp/#{daemon}") ? true : false
        Daemon.new(_daemon)
        id += 1
      end
      daemons
    end
  end

  class LoadAverage
    attr_reader :now, :min5, :min15
    def initialize
      @now, @min5, @min15 = `uptime`.split('load average:')[1].chomp.split(",").map(&:strip).map(&:to_f)
    end
  end
  class Cpu
    attr_reader :total, :kernel, :iowait
    def initialize
      all = `mpstat 1 1`.grep(/Average/)[0].chomp.split
      stats = all[2..10].map(&:to_i)
      @total = stats[0..7].sum
      @iowait = stats[3]
      @kernel = stats[2] + stats[4] + stats[5]
    end
    def stats
      { :total => total, :iowait => iowait, :kernel => kernel }
    end
  end
  class Memory
    attr_reader :total, :name, :data, :free, :used, :free_p, :used_p, :kind
    def initialize(kind)
      kind,total,used,free,shared,buffers,cached = `free -mo`.grep(kind)[0].chomp.split
      @kind = kind == 'Mem:' ? "RAM" : "Swap"
      @total = total.to_i
      @free = free.to_i + cached.to_i
      @free_p = @free * 100 / @total rescue 0
      @used = @total - @free
      @used_p = 100 - @free_p
    end
    def name
      "<b>#{kind}</b> (#{total}MB)"
    end
    def data
      [
      { :name => "#{I18n.t('dashboard.pie.free')} #{free}MB",
        :y => free_p.round, :color => '#00ff00', :sliced => true, :selected => true },
      { :name => "#{I18n.t('dashboard.pie.use')} #{used}MB",
        :y => used_p.round,:color => '#0000ff' }
      ]
    end
  end
  class Disk
    attr_reader :id, :device, :total, :total_p, :used, :used_p, :free, :free_p, :mount_point
    def initialize(a)
      number,device,total,used,free,percent,mount_point = a
      @id = "disk_" + number.to_s
      @device = device
      @total = total.to_i
      @total_g = to_g @total
      @free = free.to_i
      @free_p = @free * 100 / @total rescue 0
      @used = @total - @free
      @used_p = 100 - @free_p
      @mount_point = mount_point
    end
    def name
      "<b>#{mount_point} (#{@total_g.round}GB)</b> [#{device.sub('/dev/','')}]"
    end
    def to_g(size)
      (size / 1000 / 1000.0).round 1
    end
    def data
      [{ :name => "#{I18n.t('dashboard.pie.free')} #{to_g(free)}GB", :y => @free_p.round, :color => '#00ff00', :sliced => true, :selected => true },
      { :name => "#{I18n.t('dashboard.pie.use')} #{to_g(used)}GB", :y => @used_p.round,:color => '#0000ff' }]
    end
    def self.load_all
      ret = []
      `/bin/df -P -text3 -text4 -treiserfs`.each_with_index do |l,i|
        next if i==0;
        d = Disk.new([i] + l.split)
        ret << d
      end
      ret
    end
  end
end
