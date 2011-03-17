class AddOnlineToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :online, :boolean, :default => false
  end

  def self.down
    remove_column :providers, :online
  end
end
