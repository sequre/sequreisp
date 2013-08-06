class AddAllowDnsQueriesToProvider < ActiveRecord::Migration
  def self.up
    add_column :providers, :allow_dns_queries, :boolean, :default => false
  end

  def self.down
    remove_column :providers, :allow_dns_queries
  end
end
