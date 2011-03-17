class AddArpVarsToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :arp_ignore, :boolean, :default => true
    add_column :providers, :arp_announce, :boolean, :default => true
  end

  def self.down
    remove_column :providers, :arp_announce
    remove_column :providers, :arp_ignore
  end
end
