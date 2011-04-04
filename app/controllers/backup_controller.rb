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

class BackupController < ApplicationController
  before_filter :require_user
  before_filter :no_backups, :only => [:upload_db, :upload_full, :create_full, :create_db] if SequreispConfig::CONFIG["demo"]
  permissions :backup
  def index
  end
  def upload_db
    backup = params[:backup_db]
    if backup.nil?
      flash[:error] = t 'backup.notice.missing_file'
      redirect_to :back
    else
      backup_path = save_uploaded_file(backup)
      b = Backup.new("db", backup_path)
      if b.restore
        c = Configuration.first
        c.daemon_reload = true
        c.save
        flash[:notice] = t 'backup.notice.success_db'
      else
        flash[:error] = t 'backup.notice.error'
      end
      File.delete(backup_path)
      redirect_to :root
    end
  end
  def upload_full
    backup = params[:backup_full]
    if backup.nil?
      flash[:error] = t 'backup.notice.missing_file'
      redirect_to :back
    else
      backup_path = save_uploaded_file(backup)
      b = Backup.new("full", backup_path)
      if b.restore
        flash[:notice] = t 'backup.notice.success_full'
      else
        flash[:error] = t 'backup.notice.error'
      end
      File.delete(backup_path)
      redirect_to :root
    end
  end
  def create_full
    b = Backup.new("full", nil, params[:include_graphs])
    send_data b.to_popen.readlines.to_s,
            :type => 'application/x-gzip',
            :disposition => "attachment; filename=#{b.name}"
  end
  def create_db
    b = Backup.new("db")
    send_data b.to_popen.readlines.to_s,
            :type => 'application/x-gzip',
            :disposition => "attachment; filename=#{b.name}"
  end
  
private
  def save_uploaded_file(backup)
    tmp_dir = RAILS_ROOT + "/tmp"
    Dir.mkdir tmp_dir unless File.directory? tmp_dir
    backup_path = File.join(tmp_dir, backup['backup_file'].original_filename)
    File.open(backup_path, "wb") { |f| f.write(backup['backup_file'].read) }
    backup_path
  end
  def no_backups
    flash[:error] = I18n.t('backup.notice.no_backups_in_demo')
    redirect_to :back
  end
end
