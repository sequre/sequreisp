Factory.define :client do |f|
  f.sequence(:name) { |n| Faker::Name.name + n.to_s }
  f.sequence(:email) { |n| n.to_s + Faker::Internet.email }
  f.phone Faker::PhoneNumber.phone_number
end

Factory.define :plan do |f|
  f.sequence(:name) {|n| "Test Plan #{n}" }
  f.association :provider_group
  f.rate_down 0
  f.ceil_down 256
  f.rate_up 0
  f.ceil_up 128
  f.transparent_proxy true
end

Factory.define :contract do |f|
  f.sequence(:ip) { |n| "192.168.1.#{n}" }
  f.ceil_dfl_percent 70
  f.association :client
  f.association :plan
end

Factory.define :provider_group do |f|
  f.sequence(:name) {|n| "Test Provider Group #{n}" }
  f.after_build do |u|
    Factory.create(:provider, :provider_group => u)
  end
end

Factory.define :provider do |f|
  f.association :provider_group
  f.association :interface
  f.sequence(:name) { |n| "Test Provider#{n}" }
  f.rate_down 10000000000
  f.rate_up 10000000000
  f.sequence(:ip) { |n| "192.168.0.#{n}" }
  f.kind 'static'
  f.netmask '255.255.255.0'
  f.gateway '192.168.0.254'
end

Factory.define :interface do |f|
  f.sequence(:name) { |n| 'eth' + n.to_s }
  f.kind 'wan'
end

Factory.define :invoicing_contract, :parent => :contract do |f|
  f.association :plan, :factory => :invoicing_plan
  f.dont_create_initial_invoice true
end

Factory.define :invoicing_plan, :parent => :plan do |f|
  f.invoicing_enabled true
  f.price 100
  f.reconnection_fee 10
end

