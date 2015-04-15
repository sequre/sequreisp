class AddAttrForCirInPlan < ActiveRecord::Migration
  def self.up
    remove_column :plans, :rate_up
    remove_column :plans, :rate_down
    add_column :plans, :used_cir_percentage, :boolean, :default => false
    add_column :plans, :cir_up, :float
    add_column :plans, :cir_down, :float
    add_column :plans, :used_total_cir, :boolean, :default => false
    add_column :plans, :total_cir_up, :integer
    add_column :plans, :total_cir_down, :integer
  end

  def self.down
    add_column :plans, :rate_up, :integer
    add_column :plans, :rate_down, :integer
    remove_column :plans, :used_cir_percentage
    remove_column :plans, :cir_up
    remove_column :plans, :cir_down
    remove_column :plans, :used_total_cir
    remove_column :plans, :total_cir_up
    remove_column :plans, :total_cir_down
  end
end
