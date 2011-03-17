class CreateProviderKlasses < ActiveRecord::Migration
  def self.up
    create_table :provider_klasses do |t|
      t.integer :number
      t.integer :klassable_id
      t.string :klassable_type

      t.timestamps
    end
  end

  def self.down
    drop_table :provider_klasses
  end
end
