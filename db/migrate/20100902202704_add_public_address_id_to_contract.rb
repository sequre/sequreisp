class AddPublicAddressIdToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :public_address_id, :integer
    remove_column :contracts, :public_ip
  end

  def self.down
    add_column :contracts, :public_ip, :string
    remove_column :contracts, :public_address_id
  end
end
