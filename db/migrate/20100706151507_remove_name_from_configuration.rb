class RemoveNameFromConfiguration < ActiveRecord::Migration
  def self.up
    remove_column :configurations, :name
    remove_column :configurations, :active
  end

  def self.down
    add_column :configurations, :name, :string
    add_column :configurations, :active, :boolean
  end
end
