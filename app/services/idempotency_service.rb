# app/services/idempotency_service.rb
class IdempotencyService
  def self.find_or_create(request_id)
    record = PhiRecord.find_by(request_id: request_id)
    return record if record

    yield
  end
end
