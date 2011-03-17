class AddChargeInAdvanceToPlan < ActiveRecord::Migration
  def self.up
    add_column :plans, :charge_in_advance, :boolean, :default => false
  end

  def self.down
    remove_column :plans, :charge_in_advance
  end
end
