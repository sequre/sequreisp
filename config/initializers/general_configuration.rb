$redis = Redis.new(:host => 'localhost', :port => 6379)
$log_level = "info"

$daemon_configuration = YAML.load(File.read("#{Rails.root.to_s}/config/daemon_tasks.yml"))
Dir.glob(File.join(Rails.root, 'vendor', 'plugins', '**', 'config', 'daemon_tasks.yml')) do |dt|
  $daemon_configuration.merge!(YAML.load(File.read(dt)))
end

FileUtils.mkdir_p("#{DEPLOY_DIR}/log")
FileUtils.touch(APPLICATION_LOG) unless File.exist?(APPLICATION_LOG)

# $daemon_logger ||= Logger.new("#{DEPLOY_DIR}/log/wispro.log", shift_age = 7, shift_size = 1.megabytes)
$application_loger ||= Logger.new(APPLICATION_LOG, shift_age = 7, shift_size = 1.megabytes)

if Rails.env.development? and $0 == 'irb'
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActiveRecord::Base.connection_pool.clear_reloadable_connections!
end

# interactive editor: use vim from within irb
begin
  require 'interactive_editor'
rescue LoadError => err
  warn "Couldn't load interactive_editor: #{err}"
end

begin
  require 'awesome_print'
  AwesomePrint.irb!
rescue LoadError => err
  warn "Couldn't load awesome_print: #{err}"
end

# irb history
IRB.conf[:EVAL_HISTORY] = 1000
IRB.conf[:SAVE_HISTORY] = 1000
IRB.conf[:HISTORY_FILE] = File::expand_path("~/.irbhistory")
