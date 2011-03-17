class AddKindToInterface < ActiveRecord::Migration
  def self.up
    add_column :interfaces, :kind, :string
  end

  def self.down
    remove_column :interfaces, :kind
  end
end
