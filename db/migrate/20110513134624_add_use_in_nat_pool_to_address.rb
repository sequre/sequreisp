class AddUseInNatPoolToAddress < ActiveRecord::Migration
  def self.up
    add_column :addresses, :use_in_nat_pool, :boolean
  end

  def self.down
    remove_column :addresses, :use_in_nat_pool
  end
end
