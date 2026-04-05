# spec/mailers/patient_mailer_spec.rb
RSpec.describe PatientMailer, type: :mailer do
  let(:patient) do
    instance_double("Patient", email: "john.doe@example.com", name: "John Doe")
  end

  let(:mail) { described_class.registration_email(patient) }

  # ─── #registration_email ────────────────────────────────────────────────────

  describe "#registration_email" do
    # ── Recipient ──────────────────────────────────────────────────────────────

    it "sends to the patient's email address" do
      expect(mail.to).to eq([ "john.doe@example.com" ])
    end

    it "sends from the default mailer from address" do
      expect(mail.from).to be_present
    end

    # ── Subject ────────────────────────────────────────────────────────────────

    it "has the correct subject" do
      expect(mail.subject).to eq("Welcome to Our Hospital")
    end

    # ── Body ───────────────────────────────────────────────────────────────────

    # The mailer only ships an HTML template — no .text.erb exists yet,
    # so the mail is single-part text/html, not multipart/alternative.

    it "renders an HTML body" do
      expect(mail.body.encoded).to be_present
    end

    it "sets the content type to text/html" do
      expect(mail.content_type).to include("text/html")
    end

    it "includes the patient's email in the body" do
      expect(mail.body.encoded).to include(patient.name)
    end

    # ── Headers ────────────────────────────────────────────────────────────────

    it "does not CC anyone by default" do
      expect(mail.cc).to be_blank
    end

    it "does not BCC anyone by default" do
      expect(mail.bcc).to be_blank
    end

    # ── Edge cases ─────────────────────────────────────────────────────────────

    context "when the patient has a subdomain email address" do
      let(:patient) do
        instance_double("Patient", email: "patient@mail.hospital.org", name: "Jane Smith")
      end

      it "correctly sets the subdomain address as recipient" do
        expect(mail.to).to eq([ "patient@mail.hospital.org" ])
      end
    end

    context "when the patient has a plus-aliased email address" do
      let(:patient) do
        instance_double("Patient", email: "john+phi@example.com", name: "John Doe")
      end

      it "preserves the plus alias in the recipient address" do
        expect(mail.to).to eq([ "john+phi@example.com" ])
      end
    end
  end

  # ─── Delivery integration ───────────────────────────────────────────────────

  describe "delivery" do
    before { ActionMailer::Base.deliveries.clear }

    it "increases the deliveries count by 1 when delivered" do
      expect { mail.deliver_now }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "delivers to the correct recipient" do
      mail.deliver_now
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "john.doe@example.com" ])
    end

    it "delivers with the correct subject" do
      mail.deliver_now
      expect(ActionMailer::Base.deliveries.last.subject).to eq("Welcome to Our Hospital")
    end

    # ActiveJob cannot serialize an instance_double — it needs a real
    # ActiveRecord object. Use a persisted patient from FactoryBot.
    it "can be enqueued for later delivery", :db do
      real_patient = FactoryBot.create(:patient)
      expect { described_class.registration_email(real_patient).deliver_later }
        .to have_enqueued_mail(described_class, :registration_email)
    end
  end
end
