class CreateInterfaces < ActiveRecord::Migration
  def self.up
    create_table :interfaces do |t|
      t.string :name
      t.boolean :vlan
      t.string :vlan_id
      t.integer :vlan_interface_id

      t.timestamps
    end
  end

  def self.down
    drop_table :interfaces
  end
end
