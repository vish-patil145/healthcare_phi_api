# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  enum :role, { admin: 0, doctor: 1, nurse: 2, lab_technician: 3 }

  has_many :phi_records, foreign_key: :created_by_id, dependent: :nullify

  validates :email,
  presence: true,
  format: { with: URI::MailTo::EMAIL_REGEXP },
  uniqueness: { case_sensitive: false }
  validates :role,  inclusion: { in: roles.keys }
end
