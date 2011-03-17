class RemovePeriodicityFromPlan < ActiveRecord::Migration
  def self.up
    remove_column :plans, :periodicity
  end

  def self.down
    add_column :plans, :periodicity, :integer
  end
end
