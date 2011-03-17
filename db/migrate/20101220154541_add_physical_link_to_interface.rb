class AddPhysicalLinkToInterface < ActiveRecord::Migration
  def self.up
    add_column :interfaces, :physical_link, :boolean, :default => false
  end

  def self.down
    remove_column :interfaces, :physical_link
  end
end
