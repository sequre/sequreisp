class AddIpUniqueIndexToContract < ActiveRecord::Migration
  def self.up
    remove_index :contracts, :ip
    add_index :contracts, :ip, :unique => true
  end

  def self.down
    remove_index :contracts, :ip
    add_index :contracts, :ip
  end
end
