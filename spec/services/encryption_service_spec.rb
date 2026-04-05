# spec/services/encryption_service_spec.rb
RSpec.describe EncryptionService do
  # Shared test payloads
  let(:string_data)  { "sensitive PHI data" }
  let(:hash_data)    { { "patient_id" => 42, "diagnosis" => "hypertension" } }
  let(:array_data)   { [ "item1", "item2", 3 ] }
  let(:nil_data)     { nil }

  # ─── .encryptor ────────────────────────────────────────────────────────────

  describe ".encryptor" do
    it "returns an ActiveSupport::MessageEncryptor instance" do
      expect(described_class.encryptor).to be_a(ActiveSupport::MessageEncryptor)
    end

    it "builds a new encryptor on each call (stateless)" do
      expect(described_class.encryptor).not_to equal(described_class.encryptor)
    end
  end

  # ─── KEY constant ──────────────────────────────────────────────────────────

  describe "KEY" do
    it "is a 32-byte binary string" do
      expect(EncryptionService::KEY.bytesize).to eq(32)
    end

    it "is deterministic across calls (same key every time)" do
      key1 = Rails.application.key_generator.generate_key("phi_encryption", 32)
      expect(EncryptionService::KEY).to eq(key1)
    end
  end

  # ─── .encrypt ──────────────────────────────────────────────────────────────

  describe ".encrypt" do
    it "returns a non-nil, non-empty ciphertext string" do
      result = described_class.encrypt(string_data)
      expect(result).to be_a(String).and be_present
    end

    it "does not expose the original plaintext in the ciphertext" do
      result = described_class.encrypt(string_data)
      expect(result).not_to include(string_data)
    end

    it "produces different ciphertexts on repeated calls (random IV)" do
      first  = described_class.encrypt(string_data)
      second = described_class.encrypt(string_data)
      expect(first).not_to eq(second)
    end

    it "can encrypt a Hash payload" do
      expect { described_class.encrypt(hash_data) }.not_to raise_error
    end

    it "can encrypt an Array payload" do
      expect { described_class.encrypt(array_data) }.not_to raise_error
    end

    it "can encrypt nil (serialised as JSON null)" do
      expect { described_class.encrypt(nil_data) }.not_to raise_error
    end
  end

  # ─── .decrypt ──────────────────────────────────────────────────────────────

  describe ".decrypt" do
    it "round-trips a String back to its original value" do
      ciphertext = described_class.encrypt(string_data)
      expect(described_class.decrypt(ciphertext)).to eq(string_data)
    end

    it "round-trips a Hash back to its original value" do
      ciphertext = described_class.encrypt(hash_data)
      expect(described_class.decrypt(ciphertext)).to eq(hash_data)
    end

    it "round-trips an Array back to its original value" do
      ciphertext = described_class.encrypt(array_data)
      expect(described_class.decrypt(ciphertext)).to eq(array_data)
    end

    it "round-trips nil correctly" do
      ciphertext = described_class.encrypt(nil_data)
      expect(described_class.decrypt(ciphertext)).to be_nil
    end

    it "raises an error when given tampered ciphertext" do
      ciphertext = described_class.encrypt(string_data)
      tampered   = ciphertext.reverse

      expect { described_class.decrypt(tampered) }
        .to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
    end

    it "raises an error when given an arbitrary random string" do
      expect { described_class.decrypt("not-valid-ciphertext") }
        .to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
    end

    it "raises an error when given an empty string" do
      expect { described_class.decrypt("") }
        .to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
    end
  end

  # ─── Integration: encrypt → decrypt is idempotent ──────────────────────────

  describe "encrypt / decrypt integration" do
    let(:phi_record) do
      {
        "patient_id"  => 101,
        "name"        => "John Doe",
        "dob"         => "1980-05-14",
        "diagnosis"   => "Type 2 Diabetes",
        "ssn"         => "123-45-6789"
      }
    end

    it "preserves a realistic PHI hash through a full round-trip" do
      ciphertext = described_class.encrypt(phi_record)
      decrypted  = described_class.decrypt(ciphertext)
      expect(decrypted).to eq(phi_record)
    end

    it "each encryption of the same PHI produces a unique ciphertext" do
      ct1 = described_class.encrypt(phi_record)
      ct2 = described_class.encrypt(phi_record)
      expect(ct1).not_to eq(ct2)
    end

    it "both unique ciphertexts still decrypt to the same plaintext" do
      ct1 = described_class.encrypt(phi_record)
      ct2 = described_class.encrypt(phi_record)
      expect(described_class.decrypt(ct1)).to eq(described_class.decrypt(ct2))
    end
  end
end
