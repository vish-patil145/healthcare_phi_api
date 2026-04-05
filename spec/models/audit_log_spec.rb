require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  # ── Basic instantiation ────────────────────────────────────────────────────
  describe "instantiation" do
    it "can be instantiated" do
      expect(AuditLog.new).to be_a(AuditLog)
    end

    it "can be persisted" do
      audit_log = create(:audit_log)
      expect(audit_log).to be_persisted
    end
  end
end
