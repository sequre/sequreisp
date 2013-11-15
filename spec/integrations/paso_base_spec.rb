require 'spec_helper'

describe "Prueba Integracion" do
    
context "Paso Base" do

  it "Deberia loguearse" do

    visit ("/login")
    fill_in('user_session_email', :with => 'admin@sequre.com.ar')
    fill_in('user_session_password', :with => 1234)
    click_button 'user_session_submit'
    current_path.should eql("/contracts")

  end
 

  it "Deberia crear una Intefaz" do
    inter = Interface.new
    inter.name = 'eth1'
    inter.kind = 'wan'

    visit("/interfaces")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/interfaces/new")
    fill_in('interface_name', :with => 'eth1')
    select('WAN', :from => 'interface_kind')

    click_button 'interface_submit'
 
  end


  it "Deberia crear un Grupo de Proveedor" do
    
    providerg = ProviderGroup.new
    providerg.name = 'DHCP'
    providerg.state = 'enabled'

    visit ("/provider_groups")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/provider_groups/new")
    fill_in('provider_group_name', :with => providerg.name)
    select 'Enabled', :from => 'provider_group_state'

    click_button 'provider_group_submit'
    
  end

  it "Deberia crear un Proveedor" do
    provider = Provider.new
    provider.name = 'ITC'
    provider.state = 'enabled'
    provider.interface = Interface.find_by_name("eth1")
    provider.provider_group = ProviderGroup.first
    provider.rate_down = 2048
    provider.rate_up = 512
    provider.kind = 'dhcp'
    provider.dhcp_force_32_netmask = true

    visit("/providers")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/providers/new")
    fill_in('provider_name', :with => provider.name)
    select 'Enabled', :from => 'provider_state'
    select 'eth1', :from => 'provider_interface_id'
    select provider.provider_group.name, :from => 'provider_provider_group_id'
    fill_in('provider_rate_down', :with => provider.rate_down)
    fill_in('provider_rate_up', :with => provider.rate_up)
    select 'DHCP', :from => 'provider_kind'
    check 'provider_dhcp_force_32_netmask'
    
    click_button 'provider_submit'

  end

  it "Deberia crear un Plan" do
    plan = Plan.new
    plan.name = '2048/512'
    plan.provider_group = ProviderGroup.first
    plan.rate_down = 1024
    plan.ceil_down = 2048
    plan.rate_up = 256
    plan.ceil_up = 512

    visit("/plans")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/plans/new")
    fill_in('plan_name', :with => plan.name)
    select plan.provider_group.name, :from => 'plan_provider_group_id'
    fill_in('plan_rate_down', :with => plan.rate_down)
    fill_in('plan_ceil_down', :with => plan.rate_down)
    fill_in('plan_rate_up', :with => plan.rate_up)
    fill_in('plan_ceil_up', :with => plan.ceil_up)

    click_button 'plan_submit'

  end

  it "Deberia crear un Cliente" do
    
    client = Client.new
    client.name = "Jack Murrey"
    client.email = "jack@gmail.com"
    client.phone = 123456

    visit("/clients")
    find(:css, 'a.crear_nuevo').click
    current_path.should eql("/clients/new")
    fill_in('client_name', :with => client.name)
    fill_in('client_email', :with => client.email)
    fill_in('client_phone', :with => client.phone)
    
    click_button 'client_submit'

end

  it "Deberia crear un Contrato" do
    
    contract = Contract.new
    contract.client = Client.first
    contract.plan = Plan.first
    contract.state = "enabled"
    contract.ip = "192.168.1.2"
    contract.ceil_dfl_percent = 70

    visit("/contracts")
    find(:css, 'a.crear_nuevo').click
    current_path.should eql("/contracts/new") 
    select(contract.client.name, :from => 'contract_client_id')
    select("Enabled", :from => 'contract_state')
    select(contract.plan.name, :from => 'contract_plan_id')
    select '70', :from => 'contract_ceil_dfl_percent'

    click_button 'contract_submit'
  end

   it "Deberia desloguearse" do
    find(:css, 'a.logout').click
    current_path.should eql("/")
  end
end
end