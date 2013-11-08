class Disk < ActiveRecord::Base

  include ModelsWatcher
  watch_fields :cache, :free
  watch_on_destroy

  named_scope :system, :conditions => {:system => true}
  named_scope :cache, :conditions => {:cache => true}
  named_scope :free, :conditions => {:free => true}
  named_scope :in_raid, :conditions => ["disks.raid IS NOT NULL AND disks.system = FALSE AND disks.cache = TRUE"]
  named_scope :raid_is, lambda {|raid| { :conditions => ["disks.raid = ?", raid]} }
  named_scope :cache_in_raid, :conditions => ["disks.raid != 'md0' and disks.raid != 'NULL'"]
  before_update :clean_cache, :if => "self.free_changed? and self.free"

  def self.prepared_for string
    all.select do |d|
      d.prepare_disk_for.match(/^cache/)
    end
  end

  def clean_cache
    self.clean_partition = true
  end
  def is_mounted?
    system("mount | grep '#{name}' &>/dev/null")
  end
  def self.scan
    disks = {}
    aux =`sudo /usr/bin/lshw -C disk`.strip.split("*-")
    system_disks = used_for_system
    cache_disks = used_for_cache
    
    aux.each do |disk|
      if disk.include?("disk")
        name = ""
        capacity = ""
        serial = ""
        attributes = disk.split("  ")
        attributes.each do |attr|
          name = attr.chomp.split(":").last.strip if attr.include?("logical name")
          capacity = attr.chomp.split(":").last.split(" ").last.strip if attr.include?("size:")
          serial = attr.chomp.split(":").last.strip if attr.include?("serial")          
        end
        is_system = system_disks[:devices].include?(name) ? true : false
        is_cache = cache_disks[:devices].include?(name) ? true : false
        #which_raid = system_disks[:raid] if is_system
        #which_raid = cache_disks[:raid] if is_cache
        is_free = is_system or is_cache ? false : true
        partitioned =  is_free ? false : true
        hash = {:name => name, :capacity => capacity, :serial => serial, :system => is_system, :cache => is_cache, :free => is_free, :partitioned => partitioned, :clean_partition => is_free}
        scan_for_other_uses(hash)
        hash[:raid] = `cat /proc/mdstat | grep "#{hash[:name].split('/').last}"`.chomp.split.first
        disks[name] = hash
      end
    end
    disks
  end

  def self.scan_for_other_uses(hash)
  end

  def self.used_for_system
    self.disk_usage("on / ")
  end

  def is_system_disk?
    system "mount | grep '#{name}.*on / '"
  end

  def self.used_for_cache
    hash = {:raid => nil, :devices => []}
    devs = self.disk_usage("/mnt/sequreisp/dev")
    if devs[:devices].empty?
      devs = self.disk_usage("/mnt/cache")
      devs = self.disk_usage("/mnt/cache/web") if devs[:devices].empty?
      hash[:devices] = devs[:devices]
    else
      devs[:devices].each do |dev|
        hash[:devices] << dev if File.directory?("/mnt/sequreisp#{dev}/squid")
      end
    end
    hash[:raid] = devs[:raid]
    hash
  end

  def self.disk_usage(command)
    hash = {:raid => nil, :devices => []}
    IO.popen("mount | grep '#{command}'", "r") do |io|
      io.each do |line|
        device = line.chomp.split(" ").first
        if device.include?("md")
          hash[:raid] = device
          IO.popen("cat /proc/mdstat | grep #{device.split("/").last}", "r") do |io|
            io.each do |line|
              _cache_disks = line.chomp.split(" ")
              _cache_disks[4.._cache_disks.count].each do |disk|
                hash[:devices] << "/dev/#{disk[0..2]}"
              end
            end
          end
        else
          hash[:devices] << device.delete(device.last)
        end
      end
    end
    hash
  end

  def assigned_for(attr)
    self.free   = attr.include?(:free) ? true : false
    self.system = attr.include?(:system) ? true : false
    self.cache  = attr.include?(:cache) ? true : false
    self.save
  end

end
