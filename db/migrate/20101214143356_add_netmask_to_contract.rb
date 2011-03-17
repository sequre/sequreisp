class AddNetmaskToContract < ActiveRecord::Migration
  def self.up
    add_column :contracts, :netmask, :string
    Contract.reset_column_information
    Contract.all.each do |c|
      c.netmask = IP.new(c.ip).netmask.to_s
      Contract.update_all("netmask = '#{IP.new(c.ip).netmask.to_s}'", ['id = ?', c.id])
    end
  end

  def self.down
    remove_column :contracts, :netmask
  end
end
