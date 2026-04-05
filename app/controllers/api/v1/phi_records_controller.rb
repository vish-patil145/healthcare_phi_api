# app/controllers/api/v1/phi_records_controller.rb
class Api::V1::PhiRecordsController < ApplicationController
  before_action :set_phi_record, only: [ :show ]

  def create
    authorize PhiRecord

    request_id = request.headers["Idempotency-Key"] || SecureRandom.uuid

    # Three-layer idempotency (your existing pattern)
    existing = PhiRecord.find_by(request_id: request_id)
    return render json: existing, status: :ok if existing

    @phi_record = PhiRecord.new(
      patient_id:   params[:patient_id],
      record_type:  params[:record_type] || "general",
      status:       "pending",
      request_id:   request_id,
      created_by:   current_user
    )
    @phi_record.phi_data = params[:data].to_unsafe_h

    if @phi_record.save
      ProcessPhiJob.perform_later(@phi_record.id)
      render json: phi_record_response(@phi_record), status: :created
    else
      render json: { errors: @phi_record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    authorize PhiRecord

    records = PhiRecord.all
    records = records.by_status(params[:status])       if params[:status]
    records = records.by_patient(params[:patient_id])  if params[:patient_id]
    records = records.page(params[:page]).per(params[:per_page] || 10)

    render json: {
      data: records.map { |r| phi_record_response(r) },
      meta: {
        current_page: records.current_page,
        total_pages:  records.total_pages
      }
    }
  end

  def show
    authorize @phi_record

    render json: {
      id:          @phi_record.id,
      patient_id:  @phi_record.patient_id,
      status:      @phi_record.status,
      record_type: @phi_record.record_type,
      request_id:  @phi_record.request_id,
      data:        @phi_record.masked_data_for(current_user),  # ← role-based masking
      created_at:  @phi_record.created_at
    }
  end

  private

  def set_phi_record
    @phi_record = PhiRecord.find(params[:id])
  end

  def phi_record_response(record)
    {
      id:          record.id,
      patient_id:  record.patient_id,
      status:      record.status,
      record_type: record.record_type,
      request_id:  record.request_id,
      created_at:  record.created_at
      # ← encrypted_data intentionally excluded from list responses
    }
  end
end
