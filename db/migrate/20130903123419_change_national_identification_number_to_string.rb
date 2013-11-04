class ChangeNationalIdentificationNumberToString < ActiveRecord::Migration
  def self.up
    change_column :clients, :national_identification_number, :string
  end

  def self.down
    change_column :clients, :national_identification_number, :integer
  end
end
