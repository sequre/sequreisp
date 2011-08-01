FactoryGirl.define do

  factory :client do
    name  Faker::Name.name
    email Faker::Internet.email
    phone Faker::PhoneNumber.phone_number
  end

  factory :plan do
    name 'Test Plan'
    provider_group
    rate_down 0
    ceil_down 256
    rate_up 0
    ceil_up 128
    transparent_proxy true
  end

  factory :provider_group do
    name 'default'
  end

end


