class CreateContracts < ActiveRecord::Migration
  def self.up
    create_table :contracts do |t|
      t.integer :plan_id
      t.integer :client_id
      t.date :date_start
      t.string :ip
      t.string :mac_address
      t.string :public_ip
      t.integer :ceil_dfl_percent
      t.string :tcp_prio_ports
      t.string :udp_prio_ports
      t.string :prio_protos
      t.string :prio_helpers
      t.string :forward_ports
      t.string :state

      t.timestamps
    end
  end

  def self.down
    drop_table :contracts
  end
end
