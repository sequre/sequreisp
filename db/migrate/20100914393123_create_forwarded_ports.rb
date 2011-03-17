class CreateForwardedPorts < ActiveRecord::Migration
  def self.up
    create_table :forwarded_ports do |t|
      t.integer :contract_id
      t.integer :provider_id
      t.integer :public_port
      t.integer :private_port
      t.boolean :tcp
      t.boolean :udp

      t.timestamps
    end
  end

  def self.down
    drop_table :forwarded_ports
  end
end
