# frozen_string_literal: true

class PhiAuditProducer
  TOPIC = "phi.audit.events"

  # Publishes a PHI audit event asynchronously to Kafka.
  # Keyed by patient_id so all events for the same patient
  # land on the same partition — preserving order per patient.
  def self.publish(action:, resource:, resource_id:, user_id:, patient_id:, ip_address: nil, metadata: {})
    payload = {
      event_id:    SecureRandom.uuid,
      action:      action,
      resource:    resource,
      resource_id: resource_id,
      user_id:     user_id,
      patient_id:  patient_id,
      ip_address:  ip_address,
      metadata:    metadata,
      occurred_at: Time.current.iso8601
    }.to_json

    Karafka.producer.produce_async(
      topic:   TOPIC,
      payload: payload,
      key:     patient_id.to_s   # same partition per patient = ordered audit trail
    )
  rescue StandardError => e
    # Fail open: if Kafka is unavailable, log and move on.
    # The request must never fail because of Kafka.
    Rails.logger.error("[PhiAuditProducer] Failed to publish: #{e.message}")
  end
end
