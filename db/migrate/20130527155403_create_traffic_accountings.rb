class CreateTrafficAccountings < ActiveRecord::Migration
  def self.up
    create_table :traffics do |t|
      t.decimal :data_total, :default => 0, :precision => 20
      t.decimal :data_total_extra, :default => 0, :precision => 20
      t.decimal :data_count, :default => 0, :precision => 20
      t.date :from_date
      t.date :to_date
      t.integer :contract_id
      t.timestamps
    end
    add_index :traffics, :contract_id
  end

  def self.down
    drop_table :traffics
  end
end
