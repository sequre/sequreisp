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

class Backup
  require 'sequreisp_logger'
  CONFIG = ActiveRecord::Base.configurations[Rails.env]
  attr_reader :name

  BASE_DIR = SequreispConfig::CONFIG["base_dir"]
  DATABASE_DUMP_PATH = "#{BASE_DIR}/sequreisp.sql"

  def initialize
    require 'sequreisp_about'
    @name = "sequreisp_#{::SequreISP::Version.to_s}_backup_#{Time.now.strftime("%Y-%m-%d_%H%M")}"
  end

  def full_path
    File.join(Dir::tmpdir, name)
  end

  def mysqldump(file)
    begin
      _password = CONFIG["password"].blank? ? "" :  "-p#{CONFIG["password"]}"
      File.open file, "w" do |f|
        IO.popen("/usr/bin/mysqldump -u#{CONFIG["username"]} #{_password} #{CONFIG["database"]}") do |p|
          f.write p.read
        end
      end
      $?.exitstatus == 0
    rescue => e
      $application_logger.error(e)
      log_rescue_file(log_path, "[Model][Backup][mysqldump] #{e.message}")
      # Rails.logger.error e.inspect
    end
  end

  def backup_include_files
    paths = ["#{DATABASE_DUMP_PATH}", "#{BASE_DIR}/scripts", "#{BASE_DIR}/etc", "#{BASE_DIR}/deploy/shared/public/system"]
    paths << Configuration.first.files_include_in_backup.split("\n") rescue []
    paths.flatten.uniq.delete_if do |path| not File.exists?(path) end
  end

  def backup_exclude_files
    Configuration.first.files_exclude_in_backup.split("\n").map{|path| "--exclude=#{path}"} rescue []
  end

  def full
    if mysqldump "#{DATABASE_DUMP_PATH}"
      success = system "#{SequreispConfig::CONFIG["tar_command"]} #{backup_exclude_files.join(' ')} -zSpcf #{full_path}.tar.gz #{backup_include_files.join(' ')}"
    end
    "#{full_path}.tar.gz" if success
  end

  def flush_db
    _password = CONFIG["password"].blank? ? "" :  "-p#{CONFIG["password"]}"
    command = "/usr/bin/mysqldump --no-data --add-drop-table -u#{CONFIG["username"]} #{_password} #{CONFIG["database"]} | grep '^DROP' |  /usr/bin/mysql -u#{CONFIG["username"]} #{_password} #{CONFIG["database"]}"
    success = system(command)
    unless success
      $application_logger.error("[Model][Backup][flush_db] Failed")
      log_rescue_file(log_path, "[Model][Backup][flush_db] Failed")
    end
    # Rails.logger.error("Backup::flush_db command failed: #{command}") unless success
    success
  end

  def pop_db(sql_file, compressed=false)
    cat_command = compressed ? "zcat" : "cat"
    _password = CONFIG["password"].blank? ? "" :  "-p#{CONFIG["password"]}"
    command = "#{cat_command} #{sql_file} | /usr/bin/mysql -u#{CONFIG["username"]} #{_password} #{CONFIG["database"]}"
    $application_logger.debug("poping db with command: #{command}")
    # Rails.logger.debug "Backup:pop_db poping db with command: #{command}"
    success = system(command)
    unless success
      $application_logger.error("Backup::pop_db failed")
      log_rescue_file(log_path, "[Model][Backup][pop_db] Failed")
    end
    # Rails.logger.error("Backup::pop_db failed") unless success
    success
  end

  def restore_full(file, reboot=false, failsafe=false)
    failsafe_backup = Backup.new.full unless failsafe
    success = false
    # tar exit_status == 1 is not fatal
    if system("#{SequreispConfig::CONFIG["tar_command"]} -zxpf #{file} -C /") or $?.exitstatus == 1
      if flush_db
        success = pop_db("#{DATABASE_DUMP_PATH}")
      end
    else
      $application_logger.error("Backup::restore_full tar_command failure")
      log_rescue_file(log_path, "[Model][Backup][restore_full] Failed")
      # Rails.logger.error("Backup::restore_full tar_command failure")
    end
    unless failsafe
      if success
        respawn(reboot)
      else
        #recursive call, we use failsafe=true to avoid an infinite loop
        Backup.new.restore_full(failsafe_backup, false, true)
      end
    end
    success
  end

  def respawn(reboot)
    begin
      c = Configuration.first
      c.backup_restore = "respawn_and_boot"
      c.backup_reboot = true if reboot
      c.save(false)

      # restart passenger on restore
      # TODO handle other deploy setups
      if Rails.env.production?
        tmp_dir = RAILS_ROOT + "/tmp"
        Dir.mkdir(tmp_dir) if not File.exist? tmp_dir
        FileUtils.touch(tmp_dir + "/restart.txt")
      end

    rescue ActiveRecord::StatementInvalid, NoMethodError
      # if it is downgrading to an older version maybe backup_restore
      # and backup_reboot are not present
      #raise e.inspect
      $application_logger.info("Downgrading to a version without backup_restore or backup_reboot, need to respawn or reboot by hand")
      # Rails.logger.warn "Downgrading to a version without backup_restore or backup_reboot, need to respawn or reboot by hand"
    end
  end

  def self.is_compatible_with_this_version?(path)
    if Rails.env.production?
      backup_version = File.basename(path).match(/sequreisp_(.*)_backup/)[1] rescue nil
      backup_version.present? and ::SequreISP::Version.new(backup_version) == ::SequreISP::Version.new
    else
      true
    end
  end
end
