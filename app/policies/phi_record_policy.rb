# app/policies/phi_record_policy.rb
class PhiRecordPolicy < ApplicationPolicy
  def index?
    user.admin? || user.doctor?
  end

  def create?
    user.admin? || user.doctor?
  end

  def show?
    return true if user.admin? || user.doctor?

    # Nurse/doctor can view if consent granted to them
    Consent.exists?(
      patient_id: record.patient_id,
      granted_to: user.email,
      granted:    true
    )
  end
end
