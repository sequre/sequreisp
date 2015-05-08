class RemoveAttrShapeRateDownOnIngressInProvider < ActiveRecord::Migration
  def self.up
    remove_column :providers, :shape_rate_down_on_ingress
  end

  def self.down
    add_column :providers, :shape_rate_down_on_ingress, :boolean, :default => false
  end
end
