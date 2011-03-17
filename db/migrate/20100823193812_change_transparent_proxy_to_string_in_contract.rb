class ChangeTransparentProxyToStringInContract < ActiveRecord::Migration
  def self.up
    change_column :contracts, :transparent_proxy, :string, :default => "default"
    Contract.reset_column_information
    Contract.update_all( {:transparent_proxy => "default" } )
  end

  def self.down
    change_column :contracts, :transparent_proxy, :boolean, :default => nil
    Contract.reset_column_information
    Contract.update_all( {:transparent_proxy => nil } )
  end
end
