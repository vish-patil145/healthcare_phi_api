# app/policies/patient_policy.rb
class PatientPolicy < ApplicationPolicy
  def index?
    user.admin? || user.doctor?
  end

  def create?
    user.admin? || user.doctor?
  end

  def show?
    user.admin? || user.doctor? || user.nurse?
  end
end
