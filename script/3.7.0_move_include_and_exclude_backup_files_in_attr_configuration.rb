begin
  base_dir = SequreispConfig::CONFIG["base_dir"]
  conf = Configuration.first
  includes = []
  excludes = []
  File.open("#{base_dir}/.sequreisp_backup.include").each_line{ |line| includes << line}
  File.open("#{base_dir}/.sequreisp_backup.exclude").each_line{ |line| excludes << line}
rescue => e
  Rails.logger.error "ERROR in patch move include and exclude file to attr => #{e.inspect}"
ensure
  includes.delete("\n")
  excludes.delete("\n")
  conf.files_include_in_backup = includes.join
  conf.files_exclude_in_backup = excludes.join
  conf.save
end
