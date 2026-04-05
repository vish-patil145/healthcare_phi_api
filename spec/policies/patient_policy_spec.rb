# spec/policies/patient_policy_spec.rb
require 'rails_helper'

RSpec.describe PatientPolicy, type: :policy do
  let(:admin)  { create(:user, role: :admin) }
  let(:doctor) { create(:user, role: :doctor) }
  let(:nurse)  { create(:user, role: :nurse) }
  let(:patient) { create(:patient) }

  subject { described_class }

  permissions :index? do
    it { is_expected.to permit(admin,  patient) }
    it { is_expected.to permit(doctor, patient) }
    it { is_expected.not_to permit(nurse, patient) }
  end

  permissions :create? do
    it { is_expected.to permit(admin,  patient) }
    it { is_expected.to permit(doctor, patient) }
    it { is_expected.not_to permit(nurse, patient) }
  end

  permissions :show? do
    it { is_expected.to permit(admin,  patient) }
    it { is_expected.to permit(doctor, patient) }
    it { is_expected.to permit(nurse,  patient) }
  end
end
