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
      if Backup.new.restore_db(backup_path, @reboot)
        flash[:notice] = t 'backup.notice.success_db'
      else
        flash[:error] = t 'backup.notice.restore_error'
      end
      File.delete(backup_path)
      redirect_to :root
    end
  end
  def upload_db_and_reboot
    @reboot = true
    upload_db
  end
  def upload_full
    backup = params[:backup_full]
    if backup.nil?
      flash[:error] = t 'backup.notice.missing_file'
      redirect_to :back
    else
      backup_path = save_uploaded_file(backup)
      if Backup.new.restore_full(backup_path, @reboot)
        flash[:notice] = t 'backup.notice.success_full'
      else
        flash[:error] = t 'backup.notice.restore_error'
      end
      File.delete(backup_path)
      redirect_to :root
    end
  end
  def upload_full_and_reboot
    @reboot = true
    upload_full
  end
  def create_full
    if file = Backup.new.full(params[:include_graphs])
      send_file file, :type => 'application/x-gzip'
    else
      flash[:error] = t 'backup.notice.create_error'
      redirect_to backup_path
    end
  end
  def create_db
    if file = Backup.new.db
      send_file file, :type => 'application/x-gzip'
    else
      flash[:error] = t 'backup.notice.create_error'
      redirect_to backup_path
    end

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
