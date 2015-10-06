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

daemons = []

@general_daemon_logger ||= DaemonLogger.new("general_daemon", 0, 0)

begin
  if $running
    daemons_enabled = DaemonTask.descendants
    daemons_enabled.each do |daemon_task|
      daemon = daemon_task.new
      daemons << daemon
      daemon.start
    end
  end
rescue Exception => exception
    @general_daemon_logger.error(exception)
ensure
  begin
    while($running) do
      daemons.each do |daemon|
        unless daemon.running?
          daemon.start
          @general_daemon_logger.debug("[RESTART_DAEMON] #{daemon.name}")
        end
      end
      sleep 1
    end

    daemons.select{|d| not d.is_a_process?}.each do |daemon|
      daemon.stop
      @general_daemon_logger.info("[WAITH_FOR_DAEMON_THREAD] #{daemon.name}")
      daemon.join
    end

    daemons.select(&:is_a_process?).each do |daemon|
      @general_daemon_logger.info("[SEND_SIGNAL_TERM] #{daemon.name} (#{daemon.pid})")
      Process.kill("TERM", daemon.pid)
      status = Process.wait2(daemon.pid).last
      @general_daemon_logger.info("[WAITH_FOR_DAEMON_PROCESS] NAME: #{daemon.name} PID: #{status.pid} EXITSTATUS: #{status.exitstatus.inspect}")
    end

  rescue Exception => exception
    @general_daemon_logger.error(exception)
  end
end
#################################################
#################################################
