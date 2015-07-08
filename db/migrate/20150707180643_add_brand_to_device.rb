class AddBrandToDevice < ActiveRecord::Migration
  def self.up
    add_column :devices, :brand, :string
  end

  def self.down
    remove_column :devices, :brand, :string
  end
end
