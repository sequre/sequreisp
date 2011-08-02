Factory.define :client do |f|
  f.name Faker::Name.name
  f.email Faker::Internet.email
  f.phone Faker::PhoneNumber.phone_number
end

Factory.define :plan do |f|
  f.name 'Test Plan'
  f.association :provider_group
  f.rate_down 0
  f.ceil_down 256
  f.rate_up 0
  f.ceil_up 128
  f.transparent_proxy true
end

Factory.define :provider_group do |f|
  f.name 'Default'
end
