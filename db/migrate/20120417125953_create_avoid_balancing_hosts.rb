class CreateAvoidBalancingHosts < ActiveRecord::Migration
  def self.up
    create_table :avoid_balancing_hosts do |t|
      t.string :name
      t.integer :provider_id
      t.string :detail

      t.timestamps
    end
  end

  def self.down
    drop_table :avoid_balancing_hosts
  end
end
