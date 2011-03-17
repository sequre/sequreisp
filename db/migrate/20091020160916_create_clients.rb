class CreateClients < ActiveRecord::Migration
  def self.up
    create_table :clients do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.string :phone_mobile
      t.string :address
      t.text :details

      t.timestamps
    end
  end

  def self.down
    drop_table :clients
  end
end
