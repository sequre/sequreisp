class RemoveDefaultCeilDflPercentAndR2qFromConfiguration < ActiveRecord::Migration
  def self.up
    remove_column :configurations, :default_ceil_dfl_percent
    remove_column :configurations, :r2q
  end

  def self.down
    add_column :configurations, :default_ceil_dfl_percent, :string
    add_column :configurations, :r2q, :integer
  end
end
