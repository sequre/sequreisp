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
  CONFIG = ActiveRecord::Base.configurations[Rails.env]
  attr_reader :name

  def initialize
    require 'sequreisp_about'
    @name = "sequreisp_#{::SequreISP::Version.to_s}_backup_#{Time.now.strftime("%Y-%m-%d_%H%M")}"
  end

  def base_dir
    SequreispConfig::CONFIG["base_dir"]
  end
  def backup_include
    "#{base_dir}/.sequreisp_backup.include"
  end
  def backup_exclude
    "#{base_dir}/.sequreisp_backup.exclude"
  end
  def exclude(include_graphs)
    paths = ["/deploy/old/*", "/deploy/shared/log/*", "/deploy/shared/public/images/rrd/*"]
    paths << "/deploy/shared/db/rrd/*" unless include_graphs
    paths.each_with_object("") { |str, res| res << "--exclude=\"#{base_dir}#{str}\" " }
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
      Rails.logger.error e.inspect
    end
  end
  def db
    "#{full_path}.db.gz" if mysqldump "#{full_path}.db" and system "gzip #{full_path}.db"
  end
  def full(include_graphs=false)
    if mysqldump "#{base_dir}/sequreisp.sql"
      FileUtils.touch backup_include if not File.exists? backup_include
      FileUtils.touch backup_exclude if not File.exists? backup_exclude
      success = system "#{SequreispConfig::CONFIG["tar_command"]} #{exclude(include_graphs)} --files-from #{backup_include} --exclude-from #{backup_exclude} -zSpcf #{full_path}.tar.gz #{base_dir}"
    end
    "#{full_path}.tar.gz" if success
  end
  def full_path
    File.join(Dir::tmpdir, name)
  end
  def flush_db
    _password = CONFIG["password"].blank? ? "" :  "-p#{CONFIG["password"]}"
    command = "/usr/bin/mysqldump --no-data --add-drop-table -u#{CONFIG["username"]} #{_password} #{CONFIG["database"]} | grep '^DROP' |  /usr/bin/mysql -u#{CONFIG["username"]} #{_password} #{CONFIG["database"]}"
    success = system(command)
    Rails.logger.error("Backup::flush_db command failed: #{command}") unless success
    success
  end
  def pop_db(sql_file, compressed=false)
    cat_command = compressed ? "zcat" : "cat"
    _password = CONFIG["password"].blank? ? "" :  "-p#{CONFIG["password"]}"
    command = "#{cat_command} #{sql_file} | /usr/bin/mysql -u#{CONFIG["username"]} #{_password} #{CONFIG["database"]}"
    Rails.logger.debug "Backup:pop_db poping db with command: #{command}"
    success = system(command)
    Rails.logger.error("Backup::pop_db failed") unless success
    success
  end
  def restore_db(file, reboot=false, failsafe=false)
    failsafe_backup = Backup.new.db unless failsafe
    success = false
    if flush_db
      success = pop_db(file, true)
    end
    unless failsafe
      if success
        respawn(reboot)
      else
        #recursive call, we use failsafe=true to avoid an infinite loop
        Backup.new.restore_db(failsafe_backup, false, true)
      end
    end
    success
  end
  def restore_full(file, reboot=false, failsafe=false)
    failsafe_backup = Backup.new.full(false) unless failsafe
    success = false
    # tar exit_status == 1 is not fatal
    if system("#{SequreispConfig::CONFIG["tar_command"]} -zxpf #{file} -C /") or $?.exitstatus == 1
      if flush_db
        success = pop_db("#{base_dir}/sequreisp.sql")
      end
    else
      Rails.logger.error("Backup::restore_full tar_command failure")
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
      Rails.logger.warn "Downgrading to a version without backup_restore or backup_reboot, need to respawn or reboot by hand"
    end
  end
  def self.is_compatible_with_this_version?(path)
    backup_version = File.basename(path).match(/sequreisp_(.*)_backup/)[1] rescue nil
    backup_version.present? and ::SequreISP::Version.new(backup_version) == ::SequreISP::Version.new
  end
end

