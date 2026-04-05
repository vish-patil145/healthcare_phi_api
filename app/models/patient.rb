# app/models/patient.rb
class Patient < ApplicationRecord
  has_many :phi_records, dependent: :destroy
  has_many :consents,    dependent: :destroy

  GENDERS = %w[Male Female Other male female other].freeze

  validates :name,   presence: true
  validates :age,    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gender, presence: true, inclusion: { in: GENDERS }
  validates :email,
  presence: true,
  format: { with: URI::MailTo::EMAIL_REGEXP },
  uniqueness: { case_sensitive: false }

  after_commit :send_registration_email
  private

  def send_registration_email
    return if email.blank?
    PatientMailer.registration_email(self).deliver_later  # ← queues via Sidekiq
  end
end
