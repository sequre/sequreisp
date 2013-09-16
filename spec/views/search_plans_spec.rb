require 'spec_helper'

describe "Searching plans from view" do 

it "Login" do
  Capybara.current_driver = :selenium
  visit ("/login")
  fill_in('user_session_email', :with => 'admin@sequre.com.ar')
  fill_in('user_session_password', :with => 1234)
  click_button 'user_session_submit'
  current_path.should eql("/contracts")
end

it "Searching plan for name" do

  plan=Plan.first
  visit("/plans")
  fill_in('search_name_like', :with => plan.name)
  click_button 'search_submit'
  page.should have_css("table tr", :count=> 2 )
  page.should have_css("table tr", :text=> plan.name)

end

it "Searching plan for provider group" do

  providerg = ProviderGroup.first
  visit("/plans")
  browser = Capybara.current_session.driver.browser
  Selenium::WebDriver::Support::Select.new(browser.find_element(:id, "search_provider_group_id_equals")).select_by(:text,providerg.name)
  click_button 'search_submit'
  page.should have_css("table tr", :count=>3)
  page.should have_css("table tr", :text=> providerg.plans.first.name)
  
end

it "Searching plan for name no save" do

  visit("/plans")
  fill_in('search_name_like', :with => "Plan no existente")
  click_button 'search_submit'
  page.should have_css("table tr", :count=> 1 )

end

 it "Logout" do
    find(:css, 'a.logout').click
    current_path.should eql("/")
end

end