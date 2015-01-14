class CommandLogsController < ApplicationController
  before_filter :require_user
  permissions :command_log

  def command_log_info
    command_log_file_lines = File.open(Configuration::PATH_COMMAND_LOG, "r").readlines rescue []
    command_log_file_lines.collect!{|line| parse_line line }
    respond_to do |format|
      format.json { render :json => {:command_log_lines => command_log_file_lines }}
    end
  end

  def command_logs
  end

  private

  def parse_line line
    date, time, message, status = line.scan(/(.*) (\d+:\d+, )(.*), (true|false)/).flatten
    {:date => I18n.l(date.to_date), :time => time, :message => message, :status => status}
  end
end
