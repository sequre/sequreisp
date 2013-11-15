require 'spec_helper'
describe "Serching clients from view" do

it "Login" do
  Capybara.current_driver = :selenium
  visit ("/login")
  fill_in('user_session_email', :with => 'admin@sequre.com.ar')
  fill_in('user_session_password', :with => 1234)
  click_button 'user_session_submit'
  current_path.should eql("/contracts")
end

it "Searching client for name" do

  client=Client.first
  visit("/clients")
  fill_in('search_name_like', :with => client.name)
  click_button 'search_submit'
  page.should have_css("table tr", :count=> 2 )
  page.should have_css("table tr", :text=> client.name)

end

it "Serching client for client number" do

  visit("/clients")
  fill_in('search_number_client_like', :with => 1111111111)
  click_button 'search_submit'
  page.should have_css("table tr", :count=> 1 )

end
  
it "Logout" do
  find(:css, 'a.logout').click
  current_path.should eql("/")
end

end