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

  def initialize(kind, path=nil, include_graphs=false)
    @kind = kind
    @path = path
    @include_graphs = include_graphs
  end
  def name
    suffix = case @kind 
    when "full"
      "full.tar.gz"
    when "db"
      "db.gz"
    end
    "sequreisp_backup_#{Time.now.strftime("%Y-%m-%d_%H%M")}.#{suffix}"
  end
  def base_dir
    SequreispConfig::CONFIG["base_dir"]
  end
  def exclude
    paths = ["/deploy/old/*", "/deploy/shared/log/*", "/deploy/shared/public/images/rrd/*"]
    paths << "/deploy/shared/db/rrd/*" unless @include_graphs
    paths.each_with_object("") { |str, res| res << "--exclude=\"#{base_dir}#{str}\" " }
  end
  def to_popen 
    case @kind
    when "full"
      system("/usr/bin/mysqldump -u#{CONFIG["username"]} -p#{CONFIG["password"]} #{CONFIG["database"]} > #{base_dir}/sequreisp.sql")
      IO.popen("#{SequreispConfig::CONFIG["tar_command"]} #{exclude} --files-from #{base_dir}/.sequreisp_backup.include -zpcf - #{base_dir}")
    when "db"
      IO.popen("/usr/bin/mysqldump -u#{CONFIG["username"]} -p#{CONFIG["password"]} #{CONFIG["database"]} | gzip -")
    end
  end
  def to_file(path=".")
    File.open(File.join(path, name), "w") { |f| f.write(to_popen.read) }
  end
  def restore
    case @kind
    when "full"
      system("#{SequreispConfig::CONFIG["tar_command"]} -zxpf #{@path} -C /")
      system("cat #{base_dir}/sequreisp.sql  | /usr/bin/mysql -u#{CONFIG["username"]} -p#{CONFIG["password"]} #{CONFIG["database"]}")
    when "db"  
      system("zcat #{@path} | /usr/bin/mysql -u#{CONFIG["username"]} -p#{CONFIG["password"]} #{CONFIG["database"]}")
    end
  end
end

