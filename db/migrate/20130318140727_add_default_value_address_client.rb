class AddDefaultValueAddressClient < ActiveRecord::Migration
  def self.up
    change_column_default :clients, :address, ""
  end

  def self.down
    change_column_default :clients, :address, nil
  end
end
