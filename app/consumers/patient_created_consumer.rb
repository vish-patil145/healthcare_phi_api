# app/consumers/patient_created_consumer.rb

class PatientCreatedConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      data = message.payload.deep_symbolize_keys

      # 1. Send Welcome Email
      send_welcome_email(data)

      # 2. Create Audit Log
      create_audit_log(data)

      Rails.logger.info("[PatientCreatedConsumer] Processed patient #{data[:patient_id]}")

    rescue StandardError => e
      Rails.logger.error("[PatientCreatedConsumer] Failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end

  private

  def send_welcome_email(data)
    # PatientMailer expects a patient object — fetch it from DB
    patient = Patient.find(data[:patient_id])
    PatientMailer.registration_email(patient).deliver_now
  end

  def create_audit_log(data)
    AuditLog.create!(
      action:      "create",
      resource:    "Patient",
      resource_id: data[:patient_id],
      user_id:     data[:user_id],
      patient_id:  data[:patient_id],
      ip_address:  data[:ip_address],
      metadata:    {},
      occurred_at: data[:occurred_at]
    )
  end
end
