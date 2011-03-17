class AddArpFilterToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :arp_filter, :boolean, :default => true
  end

  def self.down
    remove_column :providers, :arp_filter
  end
end
