class AddAttrForRedirectDnsRequestToServer < ActiveRecord::Migration
  def self.up
    add_column :configurations, :redirect_external_dns_request, :boolean, :default => false
  end

  def self.down
    remove_column :configurations, :redirect_external_dns_request
  end
end
