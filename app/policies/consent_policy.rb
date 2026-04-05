# app/policies/consent_policy.rb
class ConsentPolicy < ApplicationPolicy
  # Only admin or doctor can manage consents
  def index?
    user.admin? || user.doctor?
  end

  def create?
    user.admin? || user.doctor?
  end

  def show?
    return true if user.admin? || user.doctor?

    user.nurse? && record.granted == true && record.granted_to == user.email
  end

  def update?
    user.admin? || user.doctor?
  end

  def destroy?
    user.admin? || user.doctor?
  end
end
