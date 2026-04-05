require 'rails_helper'

RSpec.describe Consent, type: :model do
  subject(:consent) { build(:consent, patient: create(:patient)) }  # ← explicit patient

  # ── Associations ───────────────────────────────────────────────────────────
  describe "associations" do
    it { is_expected.to belong_to(:patient) }
  end

  # ── Validations ────────────────────────────────────────────────────────────
  describe "validations" do
    it { is_expected.to validate_presence_of(:granted_to) }
    it { is_expected.to validate_presence_of(:patient_id) }
    it { is_expected.to validate_inclusion_of(:granted).in_array([ true, false ]) }
    it { is_expected.to validate_uniqueness_of(:granted_to).scoped_to(:patient_id) }
  end

  # ── Invalid cases ──────────────────────────────────────────────────────────
  describe "invalid cases" do
    it "is invalid without granted_to" do
      consent.granted_to = nil
      expect(consent).not_to be_valid
    end

    it "prevents duplicate consent for same patient and grantee" do
      existing = create(:consent)
      expect {
        create(:consent, patient: existing.patient, granted_to: existing.granted_to)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "allows same grantee for different patients" do
      patient_a = create(:patient)
      patient_b = create(:patient)

      create(:consent, patient: patient_a, granted_to: "nurse@hospital.com")
      second_consent = build(:consent, patient: patient_b, granted_to: "nurse@hospital.com")

      expect(second_consent).to be_valid
    end
  end

  # ── Grant/revoke behaviour ─────────────────────────────────────────────────
  describe "granted flag" do
    it "can be granted" do
      consent.granted = true
      expect(consent).to be_valid
      expect(consent.granted).to be true
    end

    it "can be revoked" do
      consent.granted = false
      expect(consent).to be_valid
      expect(consent.granted).to be false
    end
  end
end
