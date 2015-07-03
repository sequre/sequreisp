class CreateDevices < ActiveRecord::Migration
  def self.up
    create_table :devices do |t|
      t.string :host
      t.text :description
      t.string :kind # "ap", "cpe", "other", etc
      t.integer :contract_id
      t.integer :device_id

      t.timestamps
    end
  end

  def self.down
    drop_table :devices
  end
end
