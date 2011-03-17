class CreateKlasses < ActiveRecord::Migration
  def self.up
    create_table :klasses do |t|
      t.integer :contract_id
      t.integer :number

      t.timestamps
    end
  end

  def self.down
    drop_table :klasses
  end
end
