class AddInClientAttributeTaxpayerIdentificationNumber < ActiveRecord::Migration
  def self.up
    add_column :clients, :taxpayer_identification_number, :string, :default => ""
  end

  def self.down
    remove_column :clients, :taxpayer_identifitacion_number
  end
end
