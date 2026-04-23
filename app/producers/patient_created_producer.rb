# app/producers/patient_created_producer.rb

class PatientCreatedProducer        # ← must match filename exactly
  TOPIC = "phi.patient.created"

  def self.publish(patient:, user_id:, ip_address: nil)
    payload = {
      event_id:    SecureRandom.uuid,
      patient_id:  patient.id,
      user_id:     user_id,
      ip_address:  ip_address,
      occurred_at: Time.current.iso8601
    }.to_json

    Karafka.producer.produce_async(
      topic:   TOPIC,
      payload: payload,
      key:     patient.id.to_s
    )
  rescue StandardError => e
    Rails.logger.error("[PatientCreatedProducer] Failed to publish: #{e.message}")
  end
end
