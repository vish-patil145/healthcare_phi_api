class Api::V1::PatientsController < ApplicationController
  before_action :set_patient, only: [ :show ]

  def create
    @patient = Patient.new(patient_params)
    authorize @patient

    if @patient.save
      render json: @patient, status: :created
    else
      render json: { errors: @patient.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    authorize Patient
    patients = Patient.all
    patients = patients.where("name ILIKE ?", "%#{params[:name]}%") if params[:name]
    patients = patients.where(age: params[:age]) if params[:age]
    patients = patients.page(params[:page]).per(params[:per_page] || 10)

    render json: {
      data: patients,
      meta: {
        current_page: patients.current_page,
        total_pages:  patients.total_pages
      }
    }
  end

  def show
    authorize @patient
    render json: @patient
  end

  private

  def set_patient
    @patient = Patient.find(params[:id])
  end

  def patient_params
    params.permit(:name, :age, :gender, :email)
  end
end
