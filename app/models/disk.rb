class Disk < ActiveRecord::Base
  acts_as_audited

  MAX_SQUID_TOTAL_SIZE = 300*1024 #300GB
  MAX_SQUID_ON_SYSTEM_DISK_SIZE = 50 * 1024 #50GB

  acts_as_audited
  include ModelsWatcher
  watch_fields :prepare_disk_for_cache, :only_on_true => true
  watch_fields :free, :only_on_true => true
  watch_on_destroy

  named_scope :system, :conditions => {:system => true}
  named_scope :cache, :conditions => {:cache => true}
  named_scope :free, :conditions => {:free => true}
  named_scope :prepared_for_cache, :conditions => {:prepare_disk_for_cache => true}
  named_scope :assigned, :conditions => {:free => false}

  def prepare_disk_for
    _prepare_for = []
    _prepare_for << I18n.t('activerecord.attributes.disk.cache') if self.cache?
  end

  #rewrite in videocache plugin
  def assigned_to
    _assigned_to = []
    _assigned_to << I18n.t('activerecord.attributes.disk.system') if system?
    _assigned_to << I18n.t('activerecord.attributes.disk.cache') if cache?
    _assigned_to.join(" & ")
  end

  def self.scan
    result = {:new_disks => 0, :changed_disks => 0, :deleted_disks => 0}
    devices = `lsscsi | grep disk`.split("\n").collect{ |x| x.split(" ").last }

    devices.each do |dev|
      disk = Disk.find_by_name(dev)
      disk = Disk.new if disk.nil?
      disk.name = dev
      disk.raid = disk.which_raid
      disk.capacity = `sudo /sbin/fdisk -l | grep #{disk.name}:`.split(" ")[4]
      disk.serial = `sudo /sbin/blkid #{disk.name_with_partition}`.chomp.split[1].split("=")[1].delete("\"") rescue nil
      if disk.new_record?
        disk.is_used_for
        result[:new_disks] += 1
      else
        if disk.serial_changed?
          disk.assigned_for([:free]) if not disk.is_system_disk?
          result[:changed_disks] += 1
        end
      end
      disk.save
    end

    #ANY DISK DELETED?
    deleted_disks = Disk.all - Disk.find_all_by_name(devices)
    if deleted_disks.present?
      result[:deleted_disks] = deleted_disks.size
      deleted_disks.each{ |disk| disk.destroy }
    end
    result
  end

  def is_used_for
    self.system = self.is_system_disk?
    self.cache = self.is_cache_disk?
    self.free = self.is_free_disk?
  end

  def which_raid
    `cat /proc/mdstat | grep "#{self.logical_name}"`.split(" ").first
  end

  def is_system_disk?
    Kernel.system "mount | grep '#{raid.nil? ? name : raid}.*on / '"
  end

  #rewrite in videocache plugin
  def is_free_disk?
    (self.is_system_disk? or self.is_cache_disk?) ? false : true
  end

  def is_cache_disk?
    is_cache = false
    cache_dirs = `grep "^cache_dir*" /etc/squid/squid.conf`.split("\n")
    cache_dirs = `grep "^cache_dir*" /etc/squid/sequreisp.squid.conf`.split("\n") if cache_dirs.empty?
    cache_dirs.each do |cache_dir|
      dir = cache_dir.split(' ')[2]
      is_cache = `df -P #{dir} | grep '/dev'`.split(" ").first.include?("#{raid.nil? ? name : raid}") rescue false
      break if is_cache
    end
    is_cache
  end

  def is_mounted?
    Kernel.system "mount | grep '#{name}' &>/dev/null"
  end

  def assigned_for(attr)
    self.free   = attr.include?(:free) ? true : false
    self.system = attr.include?(:system) ? true : false
    self.cache  = attr.include?(:cache) ? true : false
  end

  def logical_name
    name.split("/").last
  end

  def name_with_partition
    "#{name}1"
  end

  def mounting_point
    system? ? "/var/spool" : "/mnt/sequreisp#{name}"
  end

  # Save the new Partition UUID
  def rewrite_serial
    self.serial = `sudo /sbin/blkid #{name_with_partition}`.chomp.split[1].split("=")[1].delete("\"") rescue nil
    self.save
  end

  def mount_and_add_to_fstab
    commands = []
    fstab_line = "#{name_with_partition} #{mounting_point} ext4 defaults 0 1"
    if Kernel.system "grep '#{name_with_partition}' /etc/fstab"
      commands << "sed -i \"s@^#{name_with_partition}.*@#{fstab_line}@\" /etc/fstab"
    else
      commands << "echo #{fstab_line} >> /etc/fstab"
    end
    commands << "mkdir -p #{mounting_point}"
    commands << "mount #{name_with_partition}"
  end


  def umount_and_remove_from_fstab
    [ "sed -i \"\\@#{name_with_partition}@d\" /etc/fstab",
      "umount -l #{name_with_partition}" ]
  end

  def format
    [ "dd if=/dev/zero of=#{name} count=1024 bs=1024",
      "(echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk #{name}",
      "mkfs.ext4 #{name_with_partition}" ]
  end

  def do_prepare_disk_for_cache
    commands = []
    commands << "mkdir -p #{mounting_point}/squid"
    commands << "chown proxy.proxy -R #{mounting_point}/squid" if `ls -l #{mounting_point} | grep squid`.chomp.split[2] != "proxy"
    commands
  end

  def partition_capacity
    dev = raid.present? ? "/dev/#{raid}" : name
    `sudo /sbin/fdisk -l | grep 'Disk #{dev}'`.chomp.split(" ")[4].to_i / (1024 * 1024) * 0.30 #MEGABYTE
  end

  def removed_from_raid
    if not system?
      Kernel.system "mdadm --fail /dev/#{raid} #{name_with_partition}"
      Kernel.system "mdadm --remove /dev/#{raid} #{name_with_partition}"
    end
  end

  #TODO currently not used because it is extremly slow
  # it has already a translation messages.disk.capacity_used_for_cache
  def capacity_used_for_cache
    cache? ? `du -hs #{mounting_point}/squid`.split(" ").first : "0k"
  end

  def self.not_custom_raids_present?
    all(:conditions => 'raid is not NULL and system = 0').count == 0
  end

  def self.cache_dir_lines
    lines = []
    if Disk.not_custom_raids_present?
      cache_disks = Disk.cache
      total_capacity = cache_disks.collect{|c| c.partition_capacity.to_i}.sum
      cache_disks.each do |disk|
        max_value_squid = disk.system? ? MAX_SQUID_ON_SYSTEM_DISK_SIZE : MAX_SQUID_TOTAL_SIZE
        value_for_cache_dir =  total_capacity >  max_value_squid ? (disk.partition_capacity * max_value_squid / total_capacity) : disk.partition_capacity
        lines << "cache_dir aufs #{disk.mounting_point}/squid #{value_for_cache_dir.to_i} 16 256"
      end
    else
      lines << "cache_dir aufs /var/spool/squid 30000 16 256"
    end
    lines
  end

  def auditable_name
    "#{self.class.human_name}: #{name}"
  end

end
