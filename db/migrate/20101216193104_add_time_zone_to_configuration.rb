class AddTimeZoneToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :time_zone, :string, :default => "Buenos Aires"
  end

  def self.down
    remove_column :configurations, :time_zone
  end
end
