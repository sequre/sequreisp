class CreateIproutes < ActiveRecord::Migration
  def self.up
    create_table :iproutes do |t|
      t.string :dst_address
      t.string :gateway
      t.integer :interface_id
      t.string :detail

      t.timestamps
    end
  end

  def self.down
    drop_table :iproutes
  end
end
