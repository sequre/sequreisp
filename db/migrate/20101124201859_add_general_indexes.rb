class AddGeneralIndexes < ActiveRecord::Migration
  def self.up
    add_index :clients, :name
    add_index :contracts, :plan_id
    add_index :contracts, :client_id
    add_index :contracts, :ip
    add_index :forwarded_ports, :contract_id
    add_index :klasses, :contract_id
    add_index :klasses, :number
    add_index :provider_klasses, :klassable_id
    add_index :providers, :interface_id
    add_index :addresses, :addressable_id
  end

  def self.down
    remove_index :clients, :name
    remove_index :contracts, :plan_id
    remove_index :contracts, :client_id
    remove_index :contracts, :ip
    remove_index :forwarded_ports, :contract_id
    remove_index :klasses, :contract_id
    remove_index :klasses, :number
    remove_index :provider_klasses, :klassable_id
    remove_index :providers, :interface_id
    remove_index :addresses, :addressable_id
  end
end
