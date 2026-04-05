# spec/factories/patients.rb
FactoryBot.define do
  factory :patient do
    sequence(:name) { |n| "Patient #{n}" }
    age    { 30 }
    gender { "male" }
    email  { Faker::Internet.unique.email }
  end
end
