# spec/controllers/api/v1/phi_records_controller_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::PhiRecordsController, type: :request do
  let(:admin)  { create(:user, role: :admin) }
  let(:doctor) { create(:user, role: :doctor) }
  let(:nurse)  { create(:user, role: :nurse) }

  let(:admin_headers)   { auth_headers(admin) }
  let(:doctor_headers)  { auth_headers(doctor) }
  let(:nurse_headers)   { auth_headers(nurse) }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_token' } }

  # Shared patient used by valid_params — each example gets its own via let
  let(:patient) { create(:patient) }

  let(:valid_params) do
    {
      patient_id:  patient.id,
      record_type: 'general',
      data: {
        diagnosis:    'Hypertension',
        symptoms:     [ 'headache' ],
        doctor_notes: 'Monitor BP'
      }
    }
  end

  def idempotency_headers(user_headers, key: SecureRandom.uuid)
    user_headers.merge('Idempotency-Key' => key)
  end

  def json_body
    JSON.parse(response.body)
  rescue JSON::ParserError
    raise "Response was not JSON (status #{response.status}):\n#{response.body}"
  end

  # ===========================================================================
  # POST /api/v1/phi_records
  # ===========================================================================
  describe 'POST /api/v1/phi_records' do
    context 'when authenticated as doctor with valid params' do
      it 'returns 201 created' do
        post '/api/v1/phi_records',
             params:  valid_params,
             headers: idempotency_headers(doctor_headers)
        expect(response).to have_http_status(:created)
      end

      it 'persists a new PhiRecord' do
        expect {
          post '/api/v1/phi_records',
               params:  valid_params,
               headers: idempotency_headers(doctor_headers)
        }.to change(PhiRecord, :count).by(1)
      end

      it 'returns the patient_id' do
        post '/api/v1/phi_records',
             params:  valid_params,
             headers: idempotency_headers(doctor_headers)
        expect(json_body['patient_id']).to eq(patient.id)
      end

      it 'returns status pending' do
        post '/api/v1/phi_records',
             params:  valid_params,
             headers: idempotency_headers(doctor_headers)
        expect(json_body['status']).to eq('pending')
      end

      it 'returns the idempotency key as request_id' do
        key = SecureRandom.uuid
        post '/api/v1/phi_records',
             params:  valid_params,
             headers: idempotency_headers(doctor_headers, key: key)
        expect(json_body['request_id']).to eq(key)
      end

      it 'enqueues a ProcessPhiJob' do
        expect {
          post '/api/v1/phi_records',
               params:  valid_params,
               headers: idempotency_headers(doctor_headers)
        }.to have_enqueued_job(ProcessPhiJob)
      end
    end

    context 'when authenticated as doctor with duplicate idempotency key' do
      let!(:existing) { create(:phi_record, created_by: doctor) }

      it 'returns 200 ok (idempotent)' do
        post '/api/v1/phi_records',
             params:  { patient_id: existing.patient_id, data: {} },
             headers: idempotency_headers(doctor_headers, key: existing.request_id)
        expect(response).to have_http_status(:ok)
      end

      it 'does not create a new PhiRecord' do
        expect {
          post '/api/v1/phi_records',
               params:  { patient_id: existing.patient_id, data: {} },
               headers: idempotency_headers(doctor_headers, key: existing.request_id)
        }.not_to change(PhiRecord, :count)
      end

      it 'returns the existing record id' do
        post '/api/v1/phi_records',
             params:  { patient_id: existing.patient_id, data: {} },
             headers: idempotency_headers(doctor_headers, key: existing.request_id)
        expect(json_body['id']).to eq(existing.id)
      end
    end

    context 'when authenticated as doctor with missing patient_id' do
      it 'returns 422 unprocessable entity' do
        post '/api/v1/phi_records',
             params:  { data: { diagnosis: 'X' } },
             headers: idempotency_headers(doctor_headers)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns an errors array' do
        post '/api/v1/phi_records',
             params:  { data: { diagnosis: 'X' } },
             headers: idempotency_headers(doctor_headers)
        expect(json_body['errors']).to be_an(Array).and be_present
      end

      it 'does not persist a PhiRecord' do
        expect {
          post '/api/v1/phi_records',
               params:  { data: { diagnosis: 'X' } },
               headers: idempotency_headers(doctor_headers)
        }.not_to change(PhiRecord, :count)
      end
    end

    context 'when authenticated as admin' do
      it 'returns 201 created' do
        post '/api/v1/phi_records',
             params:  valid_params,
             headers: idempotency_headers(admin_headers)
        expect(response).to have_http_status(:created)
      end

      it 'persists a new PhiRecord' do
        expect {
          post '/api/v1/phi_records',
               params:  valid_params,
               headers: idempotency_headers(admin_headers)
        }.to change(PhiRecord, :count).by(1)
      end
    end

    context 'when authenticated as nurse' do
      it 'returns 403 forbidden' do
        post '/api/v1/phi_records',
             params:  valid_params,
             headers: idempotency_headers(nurse_headers)
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not create a PhiRecord' do
        expect {
          post '/api/v1/phi_records',
               params:  valid_params,
               headers: idempotency_headers(nurse_headers)
        }.not_to change(PhiRecord, :count)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 for invalid token' do
        post '/api/v1/phi_records',
             params:  valid_params,
             headers: idempotency_headers(invalid_headers)
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 when Authorization header is absent' do
        post '/api/v1/phi_records',
             params:  valid_params,
             headers: { 'Idempotency-Key' => SecureRandom.uuid }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create a PhiRecord' do
        expect {
          post '/api/v1/phi_records',
               params:  valid_params,
               headers: idempotency_headers(invalid_headers)
        }.not_to change(PhiRecord, :count)
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/phi_records
  # ===========================================================================
  describe 'GET /api/v1/phi_records' do
    # ❌ Removed outer before { create_list(:phi_record, 5, created_by: doctor) }
    # Each nested context now owns its data to prevent cross-context pollution.

    context 'when authenticated as doctor' do
      context 'returns all records' do
        before { create_list(:phi_record, 5, created_by: doctor) }

        it 'returns 200 ok' do
          get '/api/v1/phi_records', headers: doctor_headers
          expect(response).to have_http_status(:ok)
        end

        it 'returns a data array' do
          get '/api/v1/phi_records', headers: doctor_headers
          expect(json_body['data']).to be_an(Array)
        end

        it 'returns all records' do
          get '/api/v1/phi_records', headers: doctor_headers
          expect(json_body['data'].length).to eq(5)
        end

        it 'returns current_page in meta' do
          get '/api/v1/phi_records', headers: doctor_headers
          expect(json_body['meta']['current_page']).to eq(1)
        end

        it 'returns total_pages in meta' do
          get '/api/v1/phi_records', headers: doctor_headers
          expect(json_body['meta']['total_pages']).to be >= 1
        end
      end

      # ── Status filter ──────────────────────────────────────────────────────
      context 'with status filter' do
        # Only creates the records this context needs — no outer 5 bleeding in
        before do
          create(:phi_record, status: 'processing', created_by: doctor)
          create(:phi_record, status: 'processing', created_by: doctor)
        end

        it 'returns only records matching the status' do
          get '/api/v1/phi_records',
              params:  { status: 'processing' },
              headers: doctor_headers
          statuses = json_body['data'].map { |r| r['status'] }
          expect(statuses).to all(eq('processing'))
        end

        it 'excludes records with a different status' do
          get '/api/v1/phi_records',
              params:  { status: 'processing' },
              headers: doctor_headers
          expect(json_body['data'].length).to eq(2)
        end
      end

      # ── Patient filter ─────────────────────────────────────────────────────
      context 'with patient_id filter' do
        let(:other_patient) { create(:patient) }

        before do
          create_list(:phi_record, 3, patient: patient, created_by: doctor)
          create(:phi_record, patient: other_patient, created_by: doctor)
        end

        it 'returns only records for the given patient' do
          get '/api/v1/phi_records',
              params:  { patient_id: patient.id },
              headers: doctor_headers
          ids = json_body['data'].map { |r| r['patient_id'] }
          expect(ids).to all(eq(patient.id))
        end
      end

      # ── Pagination ─────────────────────────────────────────────────────────
      context 'with pagination' do
        # Own isolated dataset — not relying on any outer before
        before { create_list(:phi_record, 5, created_by: doctor) }

        it 'returns the correct page slice' do
          get '/api/v1/phi_records',
              params:  { page: 2, per_page: 2 },
              headers: doctor_headers
          expect(json_body['data'].length).to eq(2)
        end

        it 'reflects current_page in meta' do
          get '/api/v1/phi_records',
              params:  { page: 2, per_page: 2 },
              headers: doctor_headers
          expect(json_body['meta']['current_page']).to eq(2)
        end

        it 'calculates total_pages correctly' do
          get '/api/v1/phi_records',
              params:  { page: 1, per_page: 2 },
              headers: doctor_headers
          expect(json_body['meta']['total_pages']).to eq(3)
        end

        it 'defaults to page 1 when omitted' do
          get '/api/v1/phi_records', headers: doctor_headers
          expect(json_body['meta']['current_page']).to eq(1)
        end
      end
    end

    context 'when authenticated as admin' do
      it 'returns 200 ok' do
        get '/api/v1/phi_records', headers: admin_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as nurse' do
      it 'returns 403 forbidden' do
        get '/api/v1/phi_records', headers: nurse_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 for invalid token' do
        get '/api/v1/phi_records', headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 when Authorization header is absent' do
        get '/api/v1/phi_records'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/phi_records/:id
  # ===========================================================================
  describe 'GET /api/v1/phi_records/:id' do
    let!(:phi_record) { create(:phi_record, created_by: doctor) }

    context 'when authenticated as doctor' do
      it 'returns 200 ok' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: doctor_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns the correct record id' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: doctor_headers
        expect(json_body['id']).to eq(phi_record.id)
      end

      it 'returns the patient_id' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: doctor_headers
        expect(json_body['patient_id']).to eq(phi_record.patient_id)
      end

      it 'returns the status' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: doctor_headers
        expect(json_body['status']).to eq(phi_record.status)
      end

      it 'returns the request_id' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: doctor_headers
        expect(json_body['request_id']).to eq(phi_record.request_id)
      end

      it 'returns a data key with full PHI' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: doctor_headers
        expect(json_body).to have_key('data')
      end
    end

    context 'when authenticated as admin' do
      it 'returns 200 ok' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: admin_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns a data key' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: admin_headers
        expect(json_body).to have_key('data')
      end
    end

    context 'when authenticated as nurse with consent' do
      before do
        create(:consent,
               patient_id: phi_record.patient_id,
               granted_to: nurse.email,
               granted:    true)
      end

      it 'returns 200 ok' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: nurse_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns a data key (masked for nurse role)' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: nurse_headers
        expect(json_body).to have_key('data')
      end

      it 'returns the correct record id' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: nurse_headers
        expect(json_body['id']).to eq(phi_record.id)
      end
    end

    context 'when authenticated as nurse without consent' do
      it 'returns 403 forbidden' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: nurse_headers
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns an error key' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: nurse_headers
        expect(json_body['error']).to be_present
      end
    end

    context 'when record does not exist' do
      it 'returns 404 not found' do
        get '/api/v1/phi_records/0', headers: doctor_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error message' do
        get '/api/v1/phi_records/0', headers: doctor_headers
        expect(json_body['error']).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 for invalid token' do
        get "/api/v1/phi_records/#{phi_record.id}", headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 when Authorization header is absent' do
        get "/api/v1/phi_records/#{phi_record.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
