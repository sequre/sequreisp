class DropLanguages < ActiveRecord::Migration
  def self.up
    drop_table :languages
  end

  def self.down
    create_table :languages do |t|
      t.string :name
      t.string :short_name

      t.timestamps
    end
  end
end
