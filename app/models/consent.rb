# app/models/consent.rb
class Consent < ApplicationRecord
  belongs_to :patient

  validates :granted_to,  presence: true
  validates :patient_id,  presence: true
  validates :granted,     inclusion: { in: [ true, false ] }
  validates :granted_to,  uniqueness: { scope: :patient_id }
end
