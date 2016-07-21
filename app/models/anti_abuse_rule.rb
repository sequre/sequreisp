class AntiAbuseRule < ActiveRecord::Base
  acts_as_audited
  def auditable_name
    "#{self.class.human_name}: #{tcp_port}"
  end
  validates_numericality_of :tcp_port, :only_integer => true, :greater_than => 0, :less_than_or_equal_to => 65535
  validates_numericality_of :ban_time, :only_integer => true, :greater_than => 0, :less_than_or_equal_to => 60
  validates_numericality_of :trigger_hitcount, :only_integer => true, :greater_than => 0, :less_than_or_equal_to => 20
  validates_numericality_of :trigger_seconds, :only_integer => true, :greater_than => 0, :less_than_or_equal_to => 60
  validates_presence_of :tcp_port, :ban_time, :trigger_hitcount, :trigger_seconds
  validates_uniqueness_of :tcp_port
  include ModelsWatcher
  watch_fields :tcp_port, :ban_time, :trigger_hitcount, :trigger_seconds, :enabled, :log

  def frontline_chain
    "antiabuse-front-#{tcp_port}"
  end
  def midline_chain
    "antiabuse-mid-#{tcp_port}"
  end
  def rearline_chain
    "antiabuse-rear-#{tcp_port}"
  end
  def table_seen
    "seen_#{tcp_port}"
  end
  def table_blocked
    "blocked_#{tcp_port}"
  end
  def log_prefix_seen
    "#{self.class.name}-seen-#{tcp_port} "
  end
  def log_prefix_blocked
    "#{self.class.name}-blocked-#{tcp_port} "
  end
  def get_xt_recent_info table
    current_jiffies = File.read('/proc/timer_list').match(/^jiffies.*/)[0].split[1].to_i
    current_hz = if File.exists?('/proc/config.gz')
      Zlib::GzipReader.open('/proc/config.gz') {|gz|
        gz.read.match(/CONFIG_HZ=.*/)[0].split("=")[1]
      }
    else
      kernel_release=`uname -r`
      File.read("/boot/config-#{kernel_release}").match(/CONFIG_HZ=.*/).split("=")[1]
    end
    entries = []
    File.open("/proc/net/xt_recent/#{table}", 'r').each_line do |l|
      line_array = l.split
      ip = line_array[0].split("=")[1]
      contract = Contract.find_by_ip(ip)
      last_seen = line_array[4].to_i
      packet_count = l.lenght - 8
      entries << [{:ip => ip, :contract => contract, :last_seen => Time.now-(current_jiffies - last_seen)/current_hz, :packet_count => packet_count }]
    end
    entries
  end
  def entries_seen
    get_xt_recent_info "seen" rescue []
  end
  def entries_blocked
    get_xt_recent_info "blocked" rescue []
  end
end
