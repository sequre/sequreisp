class CreateAvoidProxyHosts < ActiveRecord::Migration
  def self.up
    create_table :avoid_proxy_hosts do |t|
      t.string :name
      t.string :detail

      t.timestamps
    end
  end

  def self.down
    drop_table :avoid_proxy_hosts
  end
end
