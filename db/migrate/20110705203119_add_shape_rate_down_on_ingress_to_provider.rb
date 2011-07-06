class AddShapeRateDownOnIngressToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :shape_rate_down_on_ingress, :boolean, :default => false
  end

  def self.down
    remove_column :providers, :shape_rate_down_on_ingress
  end
end
