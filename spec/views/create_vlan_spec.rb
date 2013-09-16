require 'spec_helper'

describe "Creting elements" do

it "Login" do
 Capybara.current_driver = :selenium
  visit ("/login")
  fill_in('user_session_email', :with => 'admin@sequre.com.ar')
  fill_in('user_session_password', :with => 1234)
  click_button 'user_session_submit'
  current_path.should eql("/contracts")

end

it "Creting interface eth9 lan" do

  visit("/interfaces")
  find(:css,'a.crear_nuevo').click
  current_path.should eql("/interfaces/new")
  fill_in('interface_name', :with => 'eth9')
  browser = Capybara.current_session.driver.browser
  Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "interface_kind")).select_by(:value, "lan")
  click_button 'interface_submit'
  current_path.should eql("/interfaces")
  page.should_not have_css('div.errorExplanation')
  page.should have_css("table tr", :text=> 'eth9')

end

 it "Creating VLAN 2 wan with eth9" do

  find(:css,'a.crear_nuevo').click
  current_path.should eql("/interfaces/new")
  browser = Capybara.current_session.driver.browser
  browser.find_element(:id, "interface_vlan").click if not browser.find_element(:id, "interface_vlan").selected?
  Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "interface_vlan_interface_id")).select_by(:text, "eth9")
  fill_in('interface_vlan_id', :with => '2')
  Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "interface_kind")).select_by(:value, 'wan')
  click_button 'interface_submit'
  current_path.should eql("/interfaces")
  page.should_not have_css('div.errorExplanation')
  page.should have_css("table tr", :text=> 'eth9.2')

end

it "Creting Provider DHCP with Provider Group 1" do

    name="Provider 7"
    visit("/providers")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/providers/new")
    fill_in('provider_name', :with => name)
    browser = Capybara.current_session.driver.browser
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "provider_state")).select_by(:value, "enabled")
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "provider_interface_id")).select_by(:text,"eth1")
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "provider_provider_group_id")).select_by(:value,"1") #Test Provider Group 1
    fill_in('provider_rate_down', :with => "2147483647")
    fill_in('provider_rate_up', :with => "2147483647")
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "provider_kind")).select_by(:value, "dhcp")
    browser.find_element(:id, "provider_dhcp_force_32_netmask").click if not browser.find_element(:id, "provider_dhcp_force_32_netmask").selected?
    click_button 'provider_submit'
    current_path.should eql("/providers")
    page.should_not have_css('div.errorExplanation')
    page.should have_css("table tr", :text=> name)

end

it "Creting Provider ADSL with Provider Group 2" do

    name="Provider 8"
    visit("/providers")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/providers/new")
    fill_in('provider_name', :with => name)
    browser = Capybara.current_session.driver.browser
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "provider_state")).select_by(:value, "enabled")
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "provider_interface_id")).select_by(:text,"eth2")
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "provider_provider_group_id")).select_by(:value,"2") #Test Provider Group 2
    fill_in('provider_rate_down', :with => "2147483647")
    fill_in('provider_rate_up', :with => "2147483647")
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "provider_kind")).select_by(:value, "adsl")
    fill_in('provider_pppoe_user', :with => 'user')
    fill_in('provider_pppoe_pass', :with => 'password')
    
    click_button 'provider_submit'
    current_path.should eql("/providers")
    page.should_not have_css('div.errorExplanation')
    page.should have_css("table tr", :text=> name)

end

it "Creating Plan with Porvider Group 1" do

    name ="Plan Test 7"
    visit("/plans")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/plans/new")
    fill_in('plan_name', :with => name)
    browser = Capybara.current_session.driver.browser
    Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "plan_provider_group_id")).select_by(:value, "1") #Test Provider Group 1
    fill_in('plan_rate_down', :with => 0)
    fill_in('plan_ceil_down', :with => 512)
    fill_in('plan_rate_up', :with => 0)
    fill_in('plan_ceil_up', :with => 256)
    click_button 'plan_submit'
    current_path.should eql("/plans")
    page.should_not have_css('div.errorExplanation')
    page.should have_css("table tr", :text=> name)


end

it "Logout" do

  find(:css,'a.logout').click
  current_path.should eql("/")

end

end