require 'spec_helper2'

describe "Loading data" do

it "Should create 2 clients " do

  client = Factory.create :client
  client2= Factory.create :client
  
end

it "Should create 2 interfaces wan" do

  interface = Factory.create :interface
  interface2 = Factory.create :interface

end

it "Should create 2 contracts" do

 contract = Factory.create :contract
 contract2 = Factory.create :contract
 
end

it "Should create 1 plan" do

  plan = Factory.create :plan

end


it "Should create 1 contract disabled" do

  contract = Factory.create :contract
  contract.state='disabled'
  contract.save

end

it "Should create 2 contract for 1 client" do

  client = Factory.create :client
  contract = Factory.create :contract, :client => client
  contract2 = Factory.create :contract, :client => client

end

end

#6 clients -> 2 clients sin contrats y 1 clients con 2 contracts
#8 interfaces -> 2 sin provider
#5 contracts -> 4 Enabled - 1 Disabled
#6 plans -> 1 plan sin contract
#6 providers
#6 providers_group