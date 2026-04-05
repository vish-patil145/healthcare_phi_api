class ProcessPhiJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(record_id)
    record = PhiRecord.find(record_id)

    record.with_lock do
      return if record.status == "completed"

      record.update!(status: "processing")
    end

    sleep 3 # simulate work

    record.update!(status: "completed")
  rescue => e
    record.update!(status: "failed")
    raise e
  end
end
