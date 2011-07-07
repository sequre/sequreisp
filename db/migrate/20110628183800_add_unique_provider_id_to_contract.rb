class AddUniqueProviderIdToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :unique_provider_id, :integer
  end

  def self.down
    remove_column :contracts, :unique_provider_id
  end
end
