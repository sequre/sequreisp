class CreateProhibitedForwardPorts < ActiveRecord::Migration
  def self.up
    create_table :prohibited_forward_ports do |t|
      t.integer :port
      t.boolean :tcp
      t.boolean :udp

      t.timestamps
    end
  end

  def self.down
    drop_table :prohibited_forward_ports
  end
end
