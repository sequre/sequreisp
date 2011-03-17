class AddReloadToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :daemon_reload, :boolean
  end

  def self.down
    remove_column :configurations, :daemon_reload
  end
end
