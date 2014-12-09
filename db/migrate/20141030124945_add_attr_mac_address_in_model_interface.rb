class AddAttrMacAddressInModelInterface < ActiveRecord::Migration
  def self.up
    add_column :interfaces, :mac_address, :string
  end

  def self.down
    remove_column :interfaces, :mac_address
  end
end
