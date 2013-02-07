class AddStartDateToContract < ActiveRecord::Migration
  def self.up
  	add_column :contracts, :start_date, :date
  end

  def self.down
  	remove_column :contracts, :start_date
  end
end
