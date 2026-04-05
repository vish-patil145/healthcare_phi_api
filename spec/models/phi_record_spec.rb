require 'rails_helper'

RSpec.describe PhiRecord, type: :model do
  subject(:phi_record) { build(:phi_record) }

  # ── Associations ───────────────────────────────────────────────────────────
  describe "associations" do
    it { is_expected.to belong_to(:patient) }
    it { is_expected.to belong_to(:created_by).class_name("User") }
  end

  # ── Validations ────────────────────────────────────────────────────────────
  describe "validations" do
    it { is_expected.to validate_presence_of(:request_id) }
    it { is_expected.to validate_uniqueness_of(:request_id) }
    it { is_expected.to validate_presence_of(:record_type) }
    it { is_expected.to validate_presence_of(:encrypted_data) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[pending processing completed failed]) }
  end

  # ── Encryption ─────────────────────────────────────────────────────────────
  describe "encryption" do
    it "encrypts encrypted_data at rest" do
      phi_record.phi_data = { diagnosis: "Hypertension" }
      phi_record.save!

      raw = ActiveRecord::Base.connection
              .execute("SELECT encrypted_data FROM phi_records WHERE id = #{phi_record.id}")
              .first["encrypted_data"]

      expect(raw).not_to include("Hypertension")  # confirms it's encrypted in DB
    end
  end

  # ── phi_data helpers ───────────────────────────────────────────────────────
  describe "#phi_data=" do
    it "serializes hash to JSON and stores encrypted" do
      phi_record.phi_data = { diagnosis: "Diabetes", symptoms: [ "fatigue" ] }
      expect(phi_record.phi_data).to eq({ "diagnosis" => "Diabetes", "symptoms" => [ "fatigue" ] })
    end
  end

  describe "#phi_data" do
    it "returns empty hash on invalid JSON" do
      allow(phi_record).to receive(:encrypted_data).and_return("not-json")
      expect(phi_record.phi_data).to eq({})
    end
  end

  # ── Role-based masking ─────────────────────────────────────────────────────
  describe "#masked_data_for" do
    let(:phi_record) do
      create(:phi_record, encrypted_data: {
        diagnosis:    "Hypertension",
        doctor_notes: "Monitor BP",
        medications:  [ { name: "Amlodipine", dosage: "5mg" } ],
        lab_results:  { bp: "140/90" }
      }.to_json)
    end

    context "when user is admin" do
      it "returns full unmasked data" do
        admin = build(:user, role: :admin)
        data  = phi_record.masked_data_for(admin)
        expect(data["diagnosis"]).to eq("Hypertension")
        expect(data["doctor_notes"]).to eq("Monitor BP")
      end
    end

    context "when user is doctor" do
      it "returns full unmasked data" do
        doctor = build(:user, role: :doctor)
        data   = phi_record.masked_data_for(doctor)
        expect(data["diagnosis"]).to eq("Hypertension")
      end
    end

    context "when user is nurse" do
      it "masks diagnosis and doctor_notes" do
        nurse = build(:user, role: :nurse)
        data  = phi_record.masked_data_for(nurse)
        expect(data["diagnosis"]).to    eq("MASKED")
        expect(data["doctor_notes"]).to eq("MASKED")
        expect(data["lab_results"]).to  eq({ "bp" => "140/90" })
      end
    end

    context "when user is lab_technician" do
      it "masks diagnosis, doctor_notes and medications" do
        lab = build(:user, role: :lab_technician)
        data = phi_record.masked_data_for(lab)
        expect(data["diagnosis"]).to    eq("MASKED")
        expect(data["doctor_notes"]).to eq("MASKED")
        expect(data["medications"]).to  eq("MASKED")
        expect(data["lab_results"]).to  eq({ "bp" => "140/90" })
      end
    end
  end

  # ── Scopes ─────────────────────────────────────────────────────────────────
  describe "scopes" do
    let!(:pending_record)   { create(:phi_record, status: "pending") }
    let!(:completed_record) { create(:phi_record, status: "completed") }

    describe ".by_status" do
      it "filters by status" do
        expect(PhiRecord.by_status("pending")).to include(pending_record)
        expect(PhiRecord.by_status("pending")).not_to include(completed_record)
      end
    end

    describe ".by_patient" do
      it "filters by patient_id" do
        expect(PhiRecord.by_patient(pending_record.patient_id)).to include(pending_record)
        expect(PhiRecord.by_patient(pending_record.patient_id)).not_to include(completed_record)
      end
    end
  end
end
