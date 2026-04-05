# app/models/phi_record.rb
class PhiRecord < ApplicationRecord
  belongs_to :patient
  belongs_to :created_by, class_name: "User"

  # ── Rails 8 built-in encryption ─────────────────────────────────────────
  encrypts :encrypted_data

  # ── Validations ──────────────────────────────────────────────────────────
  validates :request_id,    presence: true, uniqueness: true
  validates :status,        inclusion: { in: %w[pending processing completed failed] }
  validates :encrypted_data, presence: true
  validates :record_type,   presence: true

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :by_status,   ->(status)     { where(status: status) }
  scope :by_patient,  ->(patient_id) { where(patient_id: patient_id) }

  # ── PHI data helpers ─────────────────────────────────────────────────────
  def phi_data
    JSON.parse(encrypted_data)
  rescue JSON::ParserError
    {}
  end

  def phi_data=(hash)
    self.encrypted_data = hash.to_json
  end

  # ── Role-based masking ───────────────────────────────────────────────────
  def masked_data_for(user)
    data = phi_data

    case user.role
    when "nurse"
      data["diagnosis"]    = "MASKED"
      data["doctor_notes"] = "MASKED"
    when "lab_technician"
      data["diagnosis"]    = "MASKED"
      data["doctor_notes"] = "MASKED"
      data["medications"]  = "MASKED"
    end

    data
  end
end
