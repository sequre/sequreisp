class CreateDisks < ActiveRecord::Migration
  def self.up
    create_table :disks do |t|
      t.string :name
      t.string :capacity
      t.boolean :system, :default => false
      t.boolean :cache, :default => false

      t.timestamps
    end
  end

  def self.down
    drop_table :disks
  end
end
