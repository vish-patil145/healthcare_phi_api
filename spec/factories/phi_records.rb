# spec/factories/phi_records.rb
FactoryBot.define do
  factory :phi_record do
    association :patient
    association :created_by, factory: :user
    record_type    { "general" }
    status         { "pending" }
    sequence(:request_id) { |n| "req-#{n}-#{SecureRandom.uuid}" }
    encrypted_data { { diagnosis: "Hypertension" }.to_json }
  end
end
