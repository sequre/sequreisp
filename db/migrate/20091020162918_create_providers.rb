class CreateProviders < ActiveRecord::Migration
  def self.up
    create_table :providers do |t|
      t.integer :provider_group_id
      t.integer :interface_id
      t.string :kind
      t.string :name
      t.string :ip
      t.string :netmask
      t.string :gateway
      t.integer :rate_down
      t.integer :rate_up
      t.string :pppoe_user
      t.string :pppoe_pass

      t.timestamps
    end
  end

  def self.down
    drop_table :providers
  end
end
