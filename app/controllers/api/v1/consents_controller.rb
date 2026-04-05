# app/controllers/api/v1/consents_controller.rb
class Api::V1::ConsentsController < ApplicationController
  before_action :set_consent, only: [ :show, :update, :destroy ]

  def create
    consent = Consent.find_or_initialize_by(
      patient_id: consent_params[:patient_id],
      granted_to: consent_params[:granted_to]
    )
    consent.assign_attributes(consent_params)
    authorize consent

    if consent.save
      render json: consent_response(consent), status: consent.previously_new_record? ? :created : :ok
    else
      render json: { errors: consent.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    authorize Consent

    consents = Consent.all
    consents = consents.where(patient_id: params[:patient_id]) if params[:patient_id]
    consents = consents.where(granted_to: params[:granted_to]) if params[:granted_to]
    consents = consents.where(granted: params[:granted])       if params[:granted].present?
    consents = consents.page(params[:page]).per(params[:per_page] || 10)

    render json: {
      data: consents.map { |c| consent_response(c) },
      meta: {
        current_page: consents.current_page,
        total_pages:  consents.total_pages
      }
    }
  end

  def show
    authorize @consent
    render json: consent_response(@consent)
  end

  def update
    authorize @consent

    if @consent.update(consent_params)
      render json: consent_response(@consent)
    else
      render json: { errors: @consent.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @consent
    @consent.destroy
    render json: { message: "Consent revoked" }
  end

  private

  def set_consent
    @consent = Consent.find(params[:id])
  end

  def consent_params
    params.permit(:patient_id, :granted_to, :granted)
  end

  def consent_response(consent)
    {
      id:         consent.id,
      patient_id: consent.patient_id,
      granted_to: consent.granted_to,
      granted:    consent.granted,
      created_at: consent.created_at,
      updated_at: consent.updated_at
    }
  end
end
