class CreateConfigurations < ActiveRecord::Migration
  def self.up
    create_table :configurations do |t|
      t.string :name
      t.string :default_tcp_prio_ports
      t.string :default_udp_prio_ports
      t.string :default_prio_protos
      t.string :default_prio_helpers
      t.string :default_ceil_dfl_percent
      t.string :rate_dfl_percent
      t.integer :mtu
      t.integer :r2q
      t.integer :class_start
      t.integer :rate_granted
      t.string :quantum_factor
      t.boolean :active

      t.timestamps
    end
  end

  def self.down
    drop_table :configurations
  end
end
