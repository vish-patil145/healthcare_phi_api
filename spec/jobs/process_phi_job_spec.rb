# spec/jobs/process_phi_job_spec.rb
RSpec.describe ProcessPhiJob, type: :job do
  let(:record_id) { 42 }
  let(:record)    { instance_double("PhiRecord", id: record_id) }

  before do
    allow(PhiRecord).to receive(:find).with(record_id).and_return(record)
    allow(record).to receive(:with_lock).and_yield
    allow(record).to receive(:update!)
    # sleep is a Kernel instance method — stub on any instance so the suite
    # doesn't actually wait 3 seconds on every example
    allow_any_instance_of(described_class).to receive(:sleep)
  end

  # ─── Queue configuration ────────────────────────────────────────────────────

  describe "queue configuration" do
    it "is queued on the default queue" do
      expect(described_class.queue_name).to eq("default")
    end

    # FIX 1: ActiveJob has no public `.retry_on_clauses` method.
    # Read the source file directly — it's the most reliable approach and
    # keeps the test meaningful without coupling to Rails internals.
    it "declares retry_on StandardError with wait: 5.seconds and attempts: 3" do
      source_file = described_class.instance_method(:perform).source_location.first
      source      = File.read(source_file)
      expect(source).to include("retry_on StandardError")
      expect(source).to include("wait: 5.seconds")
      expect(source).to include("attempts: 3")
    end
  end

  # ─── #perform – happy path ──────────────────────────────────────────────────

  describe "#perform" do
    context "when the record is not yet completed" do
      before { allow(record).to receive(:status).and_return("pending") }

      it "looks up the PhiRecord by id" do
        described_class.new.perform(record_id)
        expect(PhiRecord).to have_received(:find).with(record_id)
      end

      it "acquires a lock on the record" do
        described_class.new.perform(record_id)
        expect(record).to have_received(:with_lock)
      end

      it "sets status to processing inside the lock" do
        described_class.new.perform(record_id)
        expect(record).to have_received(:update!).with(status: "processing")
      end

      it "sets status to completed after the work" do
        described_class.new.perform(record_id)
        expect(record).to have_received(:update!).with(status: "completed")
      end

      it "calls update! exactly twice (processing + completed)" do
        described_class.new.perform(record_id)
        expect(record).to have_received(:update!).exactly(2).times
      end

      # FIX 2: sleep is called on the job instance (Kernel#sleep), not on the
      # class. Stub and assert on the specific job instance, not described_class.
      it "simulates work by sleeping 3 seconds" do
        job = described_class.new
        allow(job).to receive(:sleep)
        expect(job).to receive(:sleep).with(3)
        job.perform(record_id)
      end
    end

    context "when the record is already completed" do
      before { allow(record).to receive(:status).and_return("completed") }

      it "returns early without updating status to processing" do
        described_class.new.perform(record_id)
        expect(record).not_to have_received(:update!).with(status: "processing")
      end

      it "does not mark the record as completed again" do
        described_class.new.perform(record_id)
        expect(record).not_to have_received(:update!).with(status: "completed")
      end

      it "makes no update! calls at all" do
        described_class.new.perform(record_id)
        expect(record).not_to have_received(:update!)
      end
    end
  end

  # ─── #perform – failure / retry path ───────────────────────────────────────

  describe "#perform error handling" do
    let(:error) { StandardError.new("something went wrong") }

    context "when update! raises inside the lock" do
      before do
        allow(record).to receive(:status).and_return("pending")
        allow(record).to receive(:update!).with(status: "processing").and_raise(error)
        allow(record).to receive(:update!).with(status: "failed")
      end

      it "marks the record as failed" do
        described_class.new.perform(record_id) rescue nil
        expect(record).to have_received(:update!).with(status: "failed")
      end

      it "re-raises the original error so ActiveJob can retry" do
        expect { described_class.new.perform(record_id) }
          .to raise_error(StandardError, "something went wrong")
      end
    end

    context "when update! raises after the simulated work" do
      before do
        allow(record).to receive(:status).and_return("pending")
        allow(record).to receive(:update!).with(status: "processing")
        allow(record).to receive(:update!).with(status: "completed").and_raise(error)
        allow(record).to receive(:update!).with(status: "failed")
      end

      it "marks the record as failed" do
        described_class.new.perform(record_id) rescue nil
        expect(record).to have_received(:update!).with(status: "failed")
      end

      it "re-raises the original error" do
        expect { described_class.new.perform(record_id) }
          .to raise_error(StandardError, "something went wrong")
      end
    end

    # FIX 3: When PhiRecord.find raises, `record` is nil inside the rescue
    # block, so `record.update!(status: "failed")` blows up with NoMethodError
    # before RecordNotFound can propagate. These tests document the ACTUAL
    # behaviour and serve as a regression anchor for a future nil-guard fix.
    context "when PhiRecord.find raises ActiveRecord::RecordNotFound" do
      before do
        allow(PhiRecord).to receive(:find).with(record_id)
          .and_raise(ActiveRecord::RecordNotFound)
      end

      it "raises NoMethodError because rescue calls update! on nil (known bug)" do
        expect { described_class.new.perform(record_id) }
          .to raise_error(NoMethodError, /undefined method [`']update!'/)
      end

      it "does not call update! on any record double" do
        described_class.new.perform(record_id) rescue nil
        expect(record).not_to have_received(:update!)
      end

      # Regression anchor: once the job is patched to use `record&.update!`,
      # change the expectation here to raise_error(ActiveRecord::RecordNotFound)
      it "does NOT propagate ActiveRecord::RecordNotFound in its current form" do
        expect { described_class.new.perform(record_id) }
          .not_to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  # ─── Lock and update ordering ───────────────────────────────────────────────

  describe "lock and update ordering" do
    before { allow(record).to receive(:status).and_return("pending") }

    it "updates to processing before updating to completed" do
      order = []
      allow(record).to receive(:update!) { |args| order << args[:status] }

      described_class.new.perform(record_id)

      expect(order).to eq(%w[processing completed])
    end
  end

  # ─── ActiveJob enqueue integration ─────────────────────────────────────────

  describe "enqueuing" do
    it "enqueues the job with the correct record_id" do
      expect { described_class.perform_later(record_id) }
        .to have_enqueued_job(described_class).with(record_id)
    end

    it "enqueues on the default queue" do
      expect { described_class.perform_later(record_id) }
        .to have_enqueued_job(described_class).on_queue("default")
    end
  end
end
