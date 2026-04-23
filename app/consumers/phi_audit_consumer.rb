# frozen_string_literal: true

class PhiAuditConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      data = message.payload.deep_symbolize_keys

      AuditLog.create!(
        action:      data[:action],
        resource:    data[:resource],
        resource_id: data[:resource_id],
        user_id:     data[:user_id],
        patient_id:  data[:patient_id],
        ip_address:  data[:ip_address],
        metadata:    data[:metadata].is_a?(Hash) ? data[:metadata] : {},
        occurred_at: data[:occurred_at]
      )

      Rails.logger.info(
        "[PhiAuditConsumer] Logged #{data[:action]} on #{data[:resource]}##{data[:resource_id]} " \
        "by user #{data[:user_id]} offset=#{message.offset}"
      )
    rescue StandardError => e
      Rails.logger.error("[PhiAuditConsumer] Failed to persist audit log: #{e.message} | payload=#{message.payload}")
      Rails.logger.error(e.backtrace.join("\n"))
      # Don't re-raise — a bad message must not stall the whole partition.
      # Dead-letter queue handling can be added here later.
    end
  end
end
