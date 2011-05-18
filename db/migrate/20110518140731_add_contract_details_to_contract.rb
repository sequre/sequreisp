class AddContractDetailsToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :detail, :string
    add_column :contracts, :cpe, :string
    add_column :contracts, :node, :string
  end

  def self.down
    remove_column :contracts, :node
    remove_column :contracts, :cpe
    remove_column :contracts, :detail
  end
end
