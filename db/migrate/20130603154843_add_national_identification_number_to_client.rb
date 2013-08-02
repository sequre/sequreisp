class AddNationalIdentificationNumberToClient < ActiveRecord::Migration
  def self.up
    add_column :clients, :national_identification_number, :integer
  end

  def self.down
    remove_column :clients, :national_identification_number
  end
end
