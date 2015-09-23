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
require 'daemon_task'
require "sequreisp_logger"
require 'command_context'
#Thread::abort_on_exception = true

threads = []
begin
#################################################
#################################################
  if $running
    log("[GeneralDaemon] STARTING DAEMONS")
    DaemonTask.descendants.each do |daemon_task|
      daemon = daemon_task.new
      threads << daemon
      daemon.start
    end
  end
rescue Exception => e
  log_rescue("[Daemon][Sequreispd] ERROR GENERAL DAEMON", e)
ensure
  begin
    while($running) do
      threads.each do |thread|
        thread.start if thread.state.nil?
      end
      sleep 1
    end
    threads.map{ |thread| thread.stop }
    threads.map{ |thread| thread.join }
  rescue => e
    log_rescue("[Daemon][Sequreispd] ERROR GENERAL DAEMON", e)
  end
  log("[GeneralDaemon] DAEMONS STOPPED")
#################################################
#################################################
end
