# spec/factories/consents.rb
FactoryBot.define do
  factory :consent do
    association :patient
    association :granted_to, factory: :user
    granted     { true }
  end
end
