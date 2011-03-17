class AddLoggedInTimeoutToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :logged_in_timeout, :integer, :default => 300
  end

  def self.down
    remove_column :configurations, :logged_in_timeout
  end
end
