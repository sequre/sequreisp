require 'spec_helper'

describe "Test validation creating nothing" do


it "Login" do
    Capybara.current_driver = :selenium
    visit ("/login")
    fill_in('user_session_email', :with => 'admin@sequre.com.ar')
    fill_in('user_session_password', :with => 1234)
    click_button 'user_session_submit'
    current_path.should eql("/contracts")
end
it "Clients new" do

    visit("/clients")
    find(:css, 'a.crear_nuevo').click
    current_path.should eql("/clients/new")
    click_button 'client_submit'
    current_path.should eql("/clients")
    page.should have_css('div.errorExplanation')
    

end

it "Contracts new" do

    visit("/contracts")
    find(:css, 'a.crear_nuevo').click
    current_path.should eql("/contracts/new") 
    click_button 'contract_submit'
    page.should have_css('div.errorExplanation')

end

it "Plans new" do

    visit("/plans")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/plans/new")
    click_button 'plan_submit'
    current_path.should eql("/plans")
    page.should have_css('div.errorExplanation')

end

it "Providers new" do

    visit("/providers")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/providers/new")
    click_button 'provider_submit'
    current_path.should eql("/providers")
    page.should have_css('div.errorExplanation')

end

it "Providers groups new" do

    visit ("/provider_groups")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/provider_groups/new")
    click_button 'provider_group_submit'
    current_path.should eql("/provider_groups")
    page.should have_css('div.errorExplanation')

end
 
 it "Interfaces new" do 

    visit("/interfaces")
    find(:css,'a.crear_nuevo').click
    current_path.should eql("/interfaces/new")
    click_button 'interface_submit'
    current_path.should eql("/interfaces")
    page.should have_css('div.errorExplanation')

 end 

 it "Logout" do
    find(:css, 'a.logout').click
    current_path.should eql("/")
end



end