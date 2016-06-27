require 'sequreisp_constants'
require 'sequreisp_logger'

$redis = Redis.new(:host => 'localhost', :port => 6379)
$log_level = "info"

$daemon_configuration = YAML.load(File.read("#{Rails.root.to_s}/config/daemon_tasks.yml"))
Dir.glob(File.join(Rails.root, 'vendor', 'plugins', '**', 'config', 'daemon_tasks.yml')) do |dt|
  $daemon_configuration.merge!(YAML.load(File.read(dt)))
end

deploy = SequreispConfig::CONFIG["deploy_dir"]
app_log = "#{deploy}/log/application.log"

FileUtils.mkdir_p("#{deploy}/log")
FileUtils.touch(app_log) unless File.exist?(app_log)

# $daemon_logger ||= Logger.new("#{DEPLOY_DIR}/log/wispro.log", shift_age = 7, shift_size = 1.megabytes)
$application_logger ||= ApplicationLogger.new

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

if Rails.env.development?
  # irb history
  IRB.conf[:EVAL_HISTORY] = 1000
  IRB.conf[:SAVE_HISTORY] = 1000
  IRB.conf[:HISTORY_FILE] = File::expand_path("~/.irbhistory")
end
