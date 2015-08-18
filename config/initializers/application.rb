$redis = Redis.new(:host => 'localhost', :port => 6379)

FileUtils.mkdir_p("#{DEPLOY_DIR}/log")
FileUtils.touch(APPLICATION_LOG) unless File.exist?(APPLICATION_LOG)

$log_level = "info"
