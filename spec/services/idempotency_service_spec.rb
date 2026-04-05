# spec/services/idempotency_service_spec.rb
RSpec.describe IdempotencyService do
  describe ".find_or_create" do
    let(:request_id)    { "idempotency-key-abc123" }
    let(:existing_record) { instance_double("PhiRecord") }

    # ─── When a record already exists ──────────────────────────────────────

    context "when a PhiRecord with the given request_id already exists" do
      before do
        allow(PhiRecord).to receive(:find_by)
          .with(request_id: request_id)
          .and_return(existing_record)
      end

      it "returns the existing record" do
        result = described_class.find_or_create(request_id) { raise "should not be called" }
        expect(result).to eq(existing_record)
      end

      it "does not execute the block (idempotent short-circuit)" do
        block_called = false
        described_class.find_or_create(request_id) { block_called = true }
        expect(block_called).to be(false)
      end

      it "calls PhiRecord.find_by exactly once" do
        described_class.find_or_create(request_id) { }
        expect(PhiRecord).to have_received(:find_by).with(request_id: request_id).once
      end
    end

    # ─── When no record exists ──────────────────────────────────────────────

    context "when no PhiRecord exists for the given request_id" do
      before do
        allow(PhiRecord).to receive(:find_by)
          .with(request_id: request_id)
          .and_return(nil)
      end

      it "executes the provided block" do
        block_called = false
        described_class.find_or_create(request_id) { block_called = true }
        expect(block_called).to be(true)
      end

      it "returns the block's return value" do
        new_record = instance_double("PhiRecord")
        result = described_class.find_or_create(request_id) { new_record }
        expect(result).to eq(new_record)
      end

      it "returns nil when the block returns nil" do
        result = described_class.find_or_create(request_id) { nil }
        expect(result).to be_nil
      end

      it "calls PhiRecord.find_by exactly once" do
        described_class.find_or_create(request_id) { }
        expect(PhiRecord).to have_received(:find_by).with(request_id: request_id).once
      end
    end

    # ─── Block execution count ──────────────────────────────────────────────

    context "when called twice with the same request_id and the record exists on the second call" do
      it "executes the block only on the first call" do
        call_count = 0

        allow(PhiRecord).to receive(:find_by).with(request_id: request_id).and_return(nil, existing_record)

        described_class.find_or_create(request_id) { call_count += 1 }
        described_class.find_or_create(request_id) { call_count += 1 }

        expect(call_count).to eq(1)
      end
    end

    # ─── Block raises an error ──────────────────────────────────────────────

    context "when the block raises an error" do
      before do
        allow(PhiRecord).to receive(:find_by)
          .with(request_id: request_id)
          .and_return(nil)
      end

      it "propagates the error to the caller" do
        expect do
          described_class.find_or_create(request_id) { raise ActiveRecord::RecordInvalid }
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    # ─── No block given ────────────────────────────────────────────────────

    context "when no block is given and no record exists" do
      before do
        allow(PhiRecord).to receive(:find_by)
          .with(request_id: request_id)
          .and_return(nil)
      end

      it "raises LocalJumpError" do
        expect { described_class.find_or_create(request_id) }
          .to raise_error(LocalJumpError)
      end
    end

    context "when no block is given but a record already exists" do
      before do
        allow(PhiRecord).to receive(:find_by)
          .with(request_id: request_id)
          .and_return(existing_record)
      end

      it "returns the existing record without needing a block" do
        expect(described_class.find_or_create(request_id)).to eq(existing_record)
      end
    end

    # ─── Edge cases ────────────────────────────────────────────────────────

    context "edge cases" do
      it "handles an empty string request_id" do
        allow(PhiRecord).to receive(:find_by).with(request_id: "").and_return(nil)
        block_called = false
        described_class.find_or_create("") { block_called = true }
        expect(block_called).to be(true)
      end

      it "handles a UUID-formatted request_id" do
        uuid = SecureRandom.uuid
        allow(PhiRecord).to receive(:find_by).with(request_id: uuid).and_return(nil)
        new_record = instance_double("PhiRecord")
        result = described_class.find_or_create(uuid) { new_record }
        expect(result).to eq(new_record)
      end
    end
  end
end
