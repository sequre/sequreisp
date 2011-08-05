class RemoveChargeInAdvanceFromPlans < ActiveRecord::Migration
  def self.up
    remove_column :plans, :charge_in_advance
  end

  def self.down
    add_column :plans, :charge_in_advance, :boolean
  end
end
