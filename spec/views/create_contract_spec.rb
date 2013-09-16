require 'spec_helper'

describe "Creting contract for Client number 1" do


it "Login" do

  Capybara.current_driver = :selenium
  visit ("/login")
  fill_in('user_session_email', :with => 'admin@sequre.com.ar')
  fill_in('user_session_password', :with => 1234)
  click_button 'user_session_submit'
  current_path.should eql("/contracts")

end

it "Should create one contract" do

visit('/contracts')
find(:css, 'a.crear_nuevo').click
current_path.should eql("/contracts/new") 
browser = Capybara.current_session.driver.browser
browser.find_element(:id,'contract_client_id_chzn').click
browser.find_element(:id,'contract_client_id_chzn_o_1').click
client_number_1 = Client.find(1)
Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "contract_plan_id")).select_by(:value, 1.to_s) #Test Plan 1
Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "contract_state")).select_by(:value, "enabled")
fill_in('contract_ip', :with => '192.168.1.6')
Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "contract_ceil_dfl_percent")).select_by(:value, 50.to_s)
click_link('arping_mac_address')
click_button 'contract_submit'
current_path.should eql("/contracts")
page.should_not have_css('div.errorExplanation')
page.should have_css("table tr", :text=> client_number_1.name)

end

it "Logout" do

  find(:css,'a.logout').click
  current_path.should eql("/")

end

end