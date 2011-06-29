class AddDescriptionToInterface < ActiveRecord::Migration
  def self.up
    add_column :interfaces, :description, :string
  end

  def self.down
    remove_column :interfaces, :description
  end
end
