module Dashboard
  SERVICES= [
    { :name => I18n.t("dashboard.name_service.sequreisp_daemon_monitor"), :pattern => 'sequreispd.rb_monitor' },
    { :name => I18n.t("dashboard.name_service.sequreisp_daemon"), :pattern => 'sequreispd.rb ' },
    { :name => I18n.t("dashboard.name_service.bind_dns_server"), :pattern => 'named'},
#    { :name => I18n.t("dashboard.name_service.apache_web_server"), :pattern => 'apache2' },
    { :name => I18n.t("dashboard.name_service.mysql_server"), :pattern => 'mysqld' },
    { :name => I18n.t("dashboard.name_service.redis_server"), :pattern => 'redis-server' },
    { :name => I18n.t("dashboard.name_service.sequreisp_redis_process"), :pattern => 'sequreispd_daemon_redis ' },
    { :name => I18n.t("dashboard.name_service.sequreisp_compact_process"), :pattern => 'sequreispd_daemon_compact_samples ' }
  ]

  SERVICES << { :name => 'SSH Server', :pattern => 'sshd' } if Rails.env.development?

  class Daemon
    attr_reader :id, :name, :status, :error, :status_html

    def initialize(daemon)
      @id = daemon[:id]
      @name = I18n.t("daemons.name.#{daemon[:name]}")
      @status = daemon[:status]

      color = @status ? '#00aa00' : '#ff0000'
      word = @status ? "OK" : "ERROR"
      @status_html = "<span style=\"color: #{color}\">#{word}</span>"
    end

    def self.load_all
      id = 1
      daemons = []
      Configuration.daemons.each do |daemon|
        _daemon = {}
        _daemon[:id] = id
        _daemon[:name] = daemon
        _daemon[:status] = File.zero?("#{DEPLOY_DIR}/log/#{daemon}") ? true : false
        daemons << Daemon.new(_daemon)
        id += 1
      end
      daemons
    end
  end
end
