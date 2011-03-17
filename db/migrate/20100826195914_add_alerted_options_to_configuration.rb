class AddAlertedOptionsToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :alerted_cuts_per_hour, :integer, :default => 1
    add_column :configurations, :alerted_cut_duration, :integer, :default => 5
  end

  def self.down
    remove_column :configurations, :alerted_cut_duration
    remove_column :configurations, :alerted_cuts_per_hour
  end
end
