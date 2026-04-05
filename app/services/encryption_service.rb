# app/services/encryption_service.rb
class EncryptionService
  KEY = Rails.application.key_generator.generate_key("phi_encryption", 32)

  def self.encrypt(data)
    encryptor.encrypt_and_sign(data.to_json)
  end

  def self.decrypt(data)
    JSON.parse(encryptor.decrypt_and_verify(data))
  end

  def self.encryptor
    ActiveSupport::MessageEncryptor.new(KEY)
  end
end
