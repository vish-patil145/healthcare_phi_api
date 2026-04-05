class JwtService
  JWT_SECRET = Rails.application.credentials.dig(:jwt, :jwt_secret)

  def self.encode(payload)
    payload[:exp] = 24.hours.from_now.to_i
    JWT.encode(payload, JWT_SECRET, "HS256")
  end

  def self.decode(token)
    return nil if token.blank?
    JWT.decode(token, JWT_SECRET, true, { algorithm: "HS256" })[0]
  rescue JWT::DecodeError
    nil
  end
end
