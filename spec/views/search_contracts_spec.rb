require 'spec_helper'

describe "Searching contracts from view" do 

it "Login" do
  Capybara.current_driver = :selenium
  visit ("/login")
  fill_in('user_session_email', :with => 'admin@sequre.com.ar')
  fill_in('user_session_password', :with => 1234)
  click_button 'user_session_submit'
  current_path.should eql("/contracts")
end

it "Searching contract for name" do

  client=Client.find(6)
  visit("/contracts")
  fill_in('search_client_name_like', :with => client.name)
  click_button 'search_submit'
  page.should have_css("table tr", :count=> 3 )
  page.should have_css("table tr", :text=> client.name)
end

it "Searching contract for ip" do

  contract=Contract.first
  visit("/contracts")
  fill_in('search_ip_like', :with => contract.ip)
  click_button 'search_submit'
  page.should have_css("table tr", :count=>2)
  page.should have_css("table tr", :text=> contract.ip)

end

it "Searching contract for plan" do

  plan = Plan.first
  visit("/contracts")
  browser = Capybara.current_session.driver.browser
  Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "search_plan_id_equals")).select_by(:text,plan.name)
  click_button 'search_submit'
  page.should have_css("table tr", :count=>3)
  page.should have_css("table tr", :text=> plan.name)

end

it "Serching contract for state enabled" do

  visit("/contracts")
  browser = Capybara.current_session.driver.browser
  Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "search_state_equals")).select_by(:value, "enabled")
  click_button 'search_submit'
  page.should have_css("table tr", :count=>6)

end

it "Serching contract for state disabled" do

  visit("/contracts")
  browser = Capybara.current_session.driver.browser
  Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "search_state_equals")).select_by(:value, "disabled")
  click_button 'search_submit'
  page.should have_css("table tr", :count=>2)

end

 it "Logout" do
    find(:css, 'a.logout').click
    current_path.should eql("/")
end

end