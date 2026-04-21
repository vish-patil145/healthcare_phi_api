# frozen_string_literal: true

module KafkaAuditable
  extend ActiveSupport::Concern

  # Call this from any controller action after the main work is done.
  # Example:
  #   audit_phi_access(action: 'read', resource: 'Patient', resource_id: @patient.id, patient_id: @patient.id)
  def audit_phi_access(action:, resource:, resource_id:, patient_id:, metadata: {})
    PhiAuditProducer.publish(
      action:      action,
      resource:    resource,
      resource_id: resource_id,
      user_id:     current_user&.id,
      patient_id:  patient_id,
      ip_address:  request.remote_ip,
      metadata:    metadata
    )
  end
end