# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@hospital.com" }
    password { "password123" }
    role     { :doctor }

    trait :admin do
      role { :admin }
    end

    trait :nurse do
      role { :nurse }
    end

    trait :doctor do
      role { :doctor }
    end
  end
end
