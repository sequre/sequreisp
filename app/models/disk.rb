class Disk < ActiveRecord::Base

  include ModelsWatcher
  watch_fields :cache
  watch_on_destroy

  named_scope :system, :conditions => {:system => true}
  named_scope :cache, :conditions => {:cache => true}
  named_scope :free, :conditions => {:free => true}

  after_update :activate_mount_cache, :if => "self.cache_changed?"
  before_destroy :activate_mount_cache, :if => "self.cache_changed?"
  # before_destroy :desactive_raid HACERRRRR

  def activate_mount_cache
    conf = Configuration.first
    conf.mount_cache = true
    conf.save
  end

  def self.scan
    disks = {}
    logical_name = ""

    system_disks = used_for_system
    cache_disks = used_for_cache
    # IO.popen('sudo lshw -C disk | grep "logical name: /dev/*\| serial: \| size:"', "r") do |io|
    IO.popen('cat disklshw | /bin/grep "logical name: /dev/*\| serial: \| size:"', "r") do |io|
      io.each do |line|
        which_raid = nil
        if line.include?("logical name:")
          logical_name = line.chomp.strip.split(" ").last
          is_system = system_disks[:devices].include?(logical_name) ? true : false
          which_raid = system_disks[:raid] if is_system
          is_cache = cache_disks[:devices].include?(logical_name) ? true : false
          which_raid = cache_disks[:raid] if is_cache
          is_free = is_system or is_cache ? false : true
          disks[logical_name] = {:name => logical_name, :system => is_system, :cache => is_cache, :free => is_free, :raid => which_raid}
        elsif line.include?("serial:")
          disks[logical_name][:serial] = line.chomp.strip.split(" ").last
        elsif line.include?("size:")
          disks[logical_name][:capacity] = ((line.chomp.strip.split(" ").last).delete("(")).delete(")")
        end
      end
    end
    disks
  end

  def self.used_for_system
    hash = {:raid => "/dev/md0", :devices => []}
    # IO.popen("cat /proc/mdstat | grep md0", "r") do |io|
    IO.popen("cat mdstat | grep md0", "r") do |io|
      io.each do |line|
        _system_disks = line.chomp.split(" ")
        _system_disks[4.._system_disks.count].each do |disk|
          hash[:devices] << "/dev/#{disk[0..2]}"
        end
      end
    end
    hash[:raid] = nil if hash[:devices].empty?
    hash
  end

  def self.used_for_cache
    hash = {:raid => "/dev/md1", :devices => []}

    IO.popen("mount | grep /mtn/cache", "r") do |io|
      io.each do |line|
        hash[:devices] << line.chomp.split(" ").first
        hash[:raid] = nil
      end
    end

    # IO.popen("cat /proc/mdstat | grep md1", "r") do |io|
    IO.popen("cat mdstat | grep md1", "r") do |io|
      io.each do |line|
        _cache_disks = line.chomp.split(" ")
        _cache_disks[4.._cache_disks.count].each do |disk|
          hash[:devices] << "/dev/#{disk[0..2]}"
        end
      end
    end
    hash
  end

  def self.destroy_disks device_serials
    count = 0
    device_serials.each do |serial|
      disk = Disk.find_by_serial(serial).destroy
      count += 1
    end
    count
  end

  def self.create_or_change_disks hash_disks
    count = 0
    hash_disks.each_value do |disk|
      _disk = Disk.find_by_name(disk[:name])
      if _disk.present?
        _disk.capacity = disk[:capacity]
        _disk.system = disk[:system]
        _disk.cache = disk[:cache]
        _disk.serial = disk[:serial]
        if _disk.changed?
          _disk.save
          count += 1
        end
      else
        Disk.create disk
        count += 1
      end
    end
    count
  end

end
