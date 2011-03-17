class CreateAddresses < ActiveRecord::Migration
  def self.up
    create_table :addresses do |t|
      t.integer :addressable_id
      t.string :addressable_type
      t.string :ip
      t.string :netmask

      t.timestamps
    end
  end

  def self.down
    drop_table :addresses
  end
end
