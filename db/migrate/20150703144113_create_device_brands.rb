class CreateDeviceBrands < ActiveRecord::Migration
  def self.up
    create_table :device_brands do |t|
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :device_brands
  end
end
