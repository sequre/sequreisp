class GenerateCoreIndex < ActiveRecord::Migration
  def self.up
    add_index :plans,                 [:provider_group_id]
    add_index :devices,               [:device_id, :contract_id]
    add_index :iproutes,              [:interface_id]
    add_index :providers,             [:provider_group_id]
    add_index :interfaces,            [:vlan_id, :vlan_interface_id]
    add_index :last_samples,          [:sample_number]
    add_index :forwarded_ports,       [:provider_id]
    add_index :contract_samples,      [:period, :contract_id, :sample_number]
    add_index :interface_samples,     [:period, :interface_id, :sample_number]
    add_index :avoid_balancing_hosts, [:provider_id]
  end

  def self.down
    remove_index :plans,                 [:provider_group_id]
    remove_index :devices,               [:device_id, :contract_id]
    remove_index :iproutes,              [:interface_id]
    remove_index :providers,             [:provider_group_id]
    remove_index :interfaces,            [:vlan_id, :vlan_interface_id]
    remove_index :last_samples,          [:sample_number]
    remove_index :forwarded_ports,       [:provider_id]
    remove_index :contract_samples,      [:period, :contract_id, :sample_number]
    remove_index :interface_samples,     [:period, :interface_id, :sample_number]
    remove_index :avoid_balancing_hosts, [:provider_id]
  end
end
