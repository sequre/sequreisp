class CommandLogsController < ApplicationController
  before_filter :require_user
  permissions :command_log

  def command_log_info
    command_log_file_info = File.read(Configuration::PATH_COMMANDO_LOG) rescue ""
    respond_to do |format|
      format.json { render :json => command_log_file_info }
    end
  end

  def command_logs
  end
end
