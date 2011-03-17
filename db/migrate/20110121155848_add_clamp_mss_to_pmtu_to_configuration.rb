class AddClampMssToPmtuToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :clamp_mss_to_pmtu, :boolean, :default => true
  end

  def self.down
    remove_column :configurations, :clamp_mss_to_pmtu
  end
end
