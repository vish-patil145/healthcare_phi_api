# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "development"
require_relative "config/environment"  # ← this line is what was missing

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = {
      'bootstrap.servers': ENV.fetch('KAFKA_BOOTSTRAP_SERVERS', 'kafka:29092')
    }
    config.client_id = 'healthcare_phi_api'
    config.concurrency = 2
    config.max_wait_time = 500
    config.shutdown_timeout = 60_000
  end

  Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)

  routes.draw do
    topic 'phi.audit_events' do
      consumer PhiAuditConsumer
    end
  end
end
