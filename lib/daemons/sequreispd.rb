#!/usr/bin/env ruby

# Sequreisp - Copyright 2010, 2011 Luciano Ruete
#
# This file is part of Sequreisp.
#
# Sequreisp is free software: you can redistribute it and/or modify
# it under the terms of the GNU Afero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sequreisp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Afero General Public License for more details.
#
# You should have received a copy of the GNU Afero General Public License
# along with Sequreisp.  If not, see <http://www.gnu.org/licenses/>.

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

# load rails
require File.dirname(__FILE__) + "/../../config/environment"
# load sequreisp
require 'sequreisp'
create_dirs_if_not_present if Rails.env == 'development'

# hack arround to make daemon avaible to log to production
RAILS_DEFAULT_LOGGER.auto_flushing = 1

# our running var
Signal.trap("TERM") { $running = false }
Signal.trap("INT") { $running = false }
$running = true

require 'sequreisp_constants'
# require 'daemon_task'
require "sequreisp_logger"
require 'command_context'
#Thread::abort_on_exception = true

#################################################
#################################################

threads = []

@daemon ||= Logger.new("#{DEPLOY_DIR}/log/wispro.log", shift_age = 7, shift_size = 1.megabytes)

@daemon.formatter = proc do |severity, datetime, progname, msg|
  datetime_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
  "#{datetime_format} #{Socket.gethostname} #{SOFT_NAME}[#{Process.pid}]: [#{severity}][sequreispd.rb] #{msg} \n"
end

begin
  if $running
    daemons_enabled = DaemonTask.descendants & $daemon_configuration.select{ |key, value| value['enabled'] }.collect{|d| d.first.camelize.constantize}
    daemons_enabled.each do |daemon_task|
      daemon = daemon_task.new
      threads << daemon
      daemon.start
    end
  end
rescue Exception => exception
  @daemon.error("[MESSAGE] #{exception.message}")
  exception.backtrace.each{ |bt| @daemon.error("[BRACKTRACE] #{bt}") }
ensure
  while($running) do
    threads.each do |thread|
      thread.start if thread.state.nil?
    end
    sleep 1
  end
  threads.map{ |thread| thread.stop }
  threads.map{ |thread| thread.join }
end
#################################################
#################################################
