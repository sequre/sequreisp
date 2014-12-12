class CommandLogsController < ApplicationController
  before_filter :require_user
  permissions :command_log

  def command_log_info
    command_log_file_lines = File.open(Configuration::PATH_COMMANDO_LOG, "r").readlines rescue []
    new_lines = command_log_file_lines[params[:from_line].to_i..-1]
    new_lines.collect!{|line| parse_line line }
    respond_to do |format|
      format.json { render :json => {:last_line => (command_log_file_lines.length - 1), :command_log_lines => new_lines }}
    end
  end

  def command_logs
  end

  private

  def parse_line line
    line.scan(/.*(..:..,.*),/).first.first + " <img src='/images/check_#{line.split.last}.png'>"
  end

end
