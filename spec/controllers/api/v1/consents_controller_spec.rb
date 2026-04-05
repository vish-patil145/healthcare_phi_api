# spec/controllers/api/v1/consents_controller_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::ConsentsController, type: :request do
  let(:admin)  { create(:user, role: :admin) }
  let(:doctor) { create(:user, role: :doctor) }
  let(:nurse)  { create(:user, role: :nurse) }

  let(:admin_headers)   { auth_headers(admin) }
  let(:doctor_headers)  { auth_headers(doctor) }
  let(:nurse_headers)   { auth_headers(nurse) }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_token' } }

  let(:patient) { create(:patient) }

  def json_body
    JSON.parse(response.body)
  end

  # ===========================================================================
  # POST /api/v1/consents
  # ===========================================================================
  describe 'POST #create' do
    let(:valid_params) do
      { patient_id: patient.id, granted_to: 'nurse@example.com', granted: true }
    end
    let(:missing_granted_to_params) { { patient_id: patient.id, granted: true } }
    let(:missing_patient_id_params) { { granted_to: 'nurse@example.com', granted: true } }
    let(:empty_params)              { {} }

    context 'when authenticated as admin' do
      context 'with valid params' do
        it 'responds with 201 created' do
          post '/api/v1/consents', params: valid_params, headers: admin_headers
          expect(response).to have_http_status(:created)
        end

        it 'creates a new Consent record' do
          expect {
            post '/api/v1/consents', params: valid_params, headers: admin_headers
          }.to change(Consent, :count).by(1)
        end

        it 'returns the patient_id' do
          post '/api/v1/consents', params: valid_params, headers: admin_headers
          expect(json_body['patient_id']).to eq(patient.id)
        end

        it 'returns the granted_to' do
          post '/api/v1/consents', params: valid_params, headers: admin_headers
          expect(json_body['granted_to']).to eq('nurse@example.com')
        end

        it 'returns the granted status' do
          post '/api/v1/consents', params: valid_params, headers: admin_headers
          expect(json_body['granted']).to eq(true)
        end

        it 'returns a non-nil id' do
          post '/api/v1/consents', params: valid_params, headers: admin_headers
          expect(json_body['id']).to be_present
        end
      end

      context 'when consent for same patient_id and granted_to already exists (upsert)' do
        before { create(:consent, patient_id: patient.id, granted_to: 'nurse@example.com', granted: true) }

        it 'does not create a duplicate Consent record' do
          expect {
            post '/api/v1/consents', params: valid_params.merge(granted: false), headers: admin_headers
          }.not_to change(Consent, :count)
        end

        it 'responds with 200 ok' do
          post '/api/v1/consents', params: valid_params.merge(granted: false), headers: admin_headers
          expect(response).to have_http_status(:ok)
        end

        it 'updates the granted value on the existing record' do
          post '/api/v1/consents', params: valid_params.merge(granted: false), headers: admin_headers
          expect(json_body['granted']).to eq(false)
        end
      end

      context 'with missing granted_to' do
        it 'responds with 422 unprocessable entity' do
          post '/api/v1/consents', params: missing_granted_to_params, headers: admin_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'returns an errors array' do
          post '/api/v1/consents', params: missing_granted_to_params, headers: admin_headers
          expect(json_body['errors']).to be_an(Array).and be_present
        end

        it 'includes a granted_to-related error message' do
          post '/api/v1/consents', params: missing_granted_to_params, headers: admin_headers
          expect(json_body['errors'].join).to match(/granted to/i)
        end

        it 'does not create a Consent record' do
          expect {
            post '/api/v1/consents', params: missing_granted_to_params, headers: admin_headers
          }.not_to change(Consent, :count)
        end
      end

      context 'with missing patient_id' do
        it 'responds with 422 unprocessable entity' do
          post '/api/v1/consents', params: missing_patient_id_params, headers: admin_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'does not create a Consent record' do
          expect {
            post '/api/v1/consents', params: missing_patient_id_params, headers: admin_headers
          }.not_to change(Consent, :count)
        end
      end

      context 'with empty params' do
        it 'responds with 422 unprocessable entity' do
          post '/api/v1/consents', params: empty_params, headers: admin_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'does not create a Consent record' do
          expect {
            post '/api/v1/consents', params: empty_params, headers: admin_headers
          }.not_to change(Consent, :count)
        end
      end
    end

    context 'when authenticated as doctor' do
      it 'responds with 201 created' do
        post '/api/v1/consents', params: valid_params, headers: doctor_headers
        expect(response).to have_http_status(:created)
      end

      it 'creates a new Consent record' do
        expect {
          post '/api/v1/consents', params: valid_params, headers: doctor_headers
        }.to change(Consent, :count).by(1)
      end
    end

    context 'when authenticated as nurse' do
      it 'responds with 403 forbidden' do
        post '/api/v1/consents', params: valid_params, headers: nurse_headers
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not create a Consent record' do
        expect {
          post '/api/v1/consents', params: valid_params, headers: nurse_headers
        }.not_to change(Consent, :count)
      end
    end

    context 'when unauthenticated' do
      it 'responds with 401 for an invalid token' do
        post '/api/v1/consents', params: valid_params, headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'responds with 401 when Authorization header is absent' do
        post '/api/v1/consents', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create a Consent record' do
        expect {
          post '/api/v1/consents', params: valid_params, headers: invalid_headers
        }.not_to change(Consent, :count)
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/consents
  # ===========================================================================
  describe 'GET #index' do
    context 'when authenticated as admin' do
      before { 5.times { create(:consent) } }

      it 'responds with 200 ok' do
        get '/api/v1/consents', headers: admin_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns a data array' do
        get '/api/v1/consents', headers: admin_headers
        expect(json_body['data']).to be_an(Array)
      end

      it 'returns all consents' do
        get '/api/v1/consents', headers: admin_headers
        expect(json_body['data'].length).to eq(5)
      end

      it 'returns current_page in meta' do
        get '/api/v1/consents', headers: admin_headers
        expect(json_body['meta']['current_page']).to eq(1)
      end

      it 'returns total_pages in meta' do
        get '/api/v1/consents', headers: admin_headers
        expect(json_body['meta']['total_pages']).to be >= 1
      end

      context 'with patient_id filter' do
        let(:target_patient) { create(:patient) }
        let(:other_patient)  { create(:patient) }

        before do
          create(:consent, patient_id: target_patient.id, granted_to: 'a@example.com')
          create(:consent, patient_id: target_patient.id, granted_to: 'b@example.com')
          create(:consent, patient_id: target_patient.id, granted_to: 'c@example.com')
          create(:consent, patient_id: other_patient.id,  granted_to: 'd@example.com')
        end

        it 'returns only consents for that patient' do
          get '/api/v1/consents', params: { patient_id: target_patient.id }, headers: admin_headers
          patient_ids = json_body['data'].map { |c| c['patient_id'] }
          expect(patient_ids).to all(eq(target_patient.id))
        end

        it 'returns the correct count' do
          get '/api/v1/consents', params: { patient_id: target_patient.id }, headers: admin_headers
          expect(json_body['data'].length).to eq(3)
        end

        it 'returns empty data when patient has no consents' do
          get '/api/v1/consents', params: { patient_id: create(:patient).id }, headers: admin_headers
          expect(json_body['data']).to be_empty
        end
      end

      context 'with granted_to filter' do
        before do
          create(:consent, granted_to: 'target@example.com')
          create(:consent, granted_to: 'other@example.com')
        end

        it 'returns only consents for that granted_to value' do
          get '/api/v1/consents', params: { granted_to: 'target@example.com' }, headers: admin_headers
          granted_tos = json_body['data'].map { |c| c['granted_to'] }
          expect(granted_tos).to all(eq('target@example.com'))
        end

        it 'returns empty data when no consents match' do
          get '/api/v1/consents', params: { granted_to: 'nobody@example.com' }, headers: admin_headers
          expect(json_body['data']).to be_empty
        end
      end

      context 'with granted filter' do
        before do
          create(:consent, granted: true,  granted_to: 'a@example.com')
          create(:consent, granted: true,  granted_to: 'b@example.com')
          create(:consent, granted: false, granted_to: 'c@example.com')
        end

        it 'returns only granted consents when granted=true' do
          get '/api/v1/consents', params: { granted: true }, headers: admin_headers
          granted_values = json_body['data'].map { |c| c['granted'] }
          expect(granted_values).to all(eq(true))
        end

        it 'returns only revoked consents when granted=false' do
          get '/api/v1/consents', params: { granted: false }, headers: admin_headers
          granted_values = json_body['data'].map { |c| c['granted'] }
          expect(granted_values).to all(eq(false))
        end
      end

      context 'with pagination' do
        before { 5.times { create(:consent) } } # 10 total with outer before

        it 'returns the correct page slice' do
          get '/api/v1/consents', params: { page: 2, per_page: 4 }, headers: admin_headers
          expect(json_body['data'].length).to eq(4)
        end

        it 'reflects current_page correctly in meta' do
          get '/api/v1/consents', params: { page: 2, per_page: 4 }, headers: admin_headers
          expect(json_body['meta']['current_page']).to eq(2)
        end

        it 'calculates total_pages correctly' do
          get '/api/v1/consents', params: { page: 1, per_page: 4 }, headers: admin_headers
          expect(json_body['meta']['total_pages']).to eq(3)
        end

        it 'defaults to page 1 when page param is omitted' do
          get '/api/v1/consents', headers: admin_headers
          expect(json_body['meta']['current_page']).to eq(1)
        end
      end
    end

    context 'when authenticated as doctor' do
      it 'responds with 200 ok' do
        get '/api/v1/consents', headers: doctor_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as nurse' do
      it 'responds with 403 forbidden' do
        get '/api/v1/consents', headers: nurse_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'responds with 401 for an invalid token' do
        get '/api/v1/consents', headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'responds with 401 when Authorization header is absent' do
        get '/api/v1/consents'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/consents/:id
  # ===========================================================================
  describe 'GET #show' do
    let(:consent) { create(:consent) }

    context 'when authenticated as admin' do
      it 'responds with 200 ok' do
        get "/api/v1/consents/#{consent.id}", headers: admin_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns the correct id' do
        get "/api/v1/consents/#{consent.id}", headers: admin_headers
        expect(json_body['id']).to eq(consent.id)
      end

      it 'returns the correct patient_id' do
        get "/api/v1/consents/#{consent.id}", headers: admin_headers
        expect(json_body['patient_id']).to eq(consent.patient_id)
      end

      it 'returns the correct granted_to' do
        get "/api/v1/consents/#{consent.id}", headers: admin_headers
        expect(json_body['granted_to']).to eq(consent.granted_to)
      end

      it 'returns the correct granted status' do
        get "/api/v1/consents/#{consent.id}", headers: admin_headers
        expect(json_body['granted']).to eq(consent.granted)
      end
    end

    context 'when authenticated as doctor' do
      it 'responds with 200 ok' do
        get "/api/v1/consents/#{consent.id}", headers: doctor_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as nurse' do
      context 'when consent is granted to the nurse' do
        let(:consent) { create(:consent, granted: true, granted_to: nurse.email) }

        it 'responds with 200 ok' do
          get "/api/v1/consents/#{consent.id}", headers: nurse_headers
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when consent is not granted' do
        let(:consent) { create(:consent, granted: false, granted_to: nurse.email) }

        it 'responds with 403 forbidden' do
          get "/api/v1/consents/#{consent.id}", headers: nurse_headers
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when consent is granted to a different nurse' do
        let(:consent) { create(:consent, granted: true, granted_to: 'other_nurse@example.com') }

        it 'responds with 403 forbidden' do
          get "/api/v1/consents/#{consent.id}", headers: nurse_headers
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'when consent does not exist' do
      it 'responds with 404 not found' do
        get '/api/v1/consents/0', headers: admin_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error message' do
        get '/api/v1/consents/0', headers: admin_headers
        expect(json_body['error']).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'responds with 401 for an invalid token' do
        get "/api/v1/consents/#{consent.id}", headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'responds with 401 when Authorization header is absent' do
        get "/api/v1/consents/#{consent.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================================================
  # PATCH /api/v1/consents/:id
  # ===========================================================================
  describe 'PATCH #update' do
    let(:consent) { create(:consent, granted: true, granted_to: 'nurse@example.com') }

    context 'when authenticated as admin' do
      context 'with valid params' do
        it 'responds with 200 ok' do
          patch "/api/v1/consents/#{consent.id}", params: { granted: false }, headers: admin_headers
          expect(response).to have_http_status(:ok)
        end

        it 'updates the granted status' do
          patch "/api/v1/consents/#{consent.id}", params: { granted: false }, headers: admin_headers
          expect(json_body['granted']).to eq(false)
        end

        it 'updates the granted_to value' do
          patch "/api/v1/consents/#{consent.id}", params: { granted_to: 'new@example.com' }, headers: admin_headers
          expect(json_body['granted_to']).to eq('new@example.com')
        end
      end

      context 'with invalid params' do
        it 'responds with 422 unprocessable entity' do
          patch "/api/v1/consents/#{consent.id}", params: { granted_to: '' }, headers: admin_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'returns an errors array' do
          patch "/api/v1/consents/#{consent.id}", params: { granted_to: '' }, headers: admin_headers
          expect(json_body['errors']).to be_an(Array).and be_present
        end
      end

      context 'when consent does not exist' do
        it 'responds with 404 not found' do
          patch '/api/v1/consents/0', params: { granted: false }, headers: admin_headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when authenticated as doctor' do
      it 'responds with 200 ok' do
        patch "/api/v1/consents/#{consent.id}", params: { granted: false }, headers: doctor_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as nurse' do
      it 'responds with 403 forbidden' do
        patch "/api/v1/consents/#{consent.id}", params: { granted: false }, headers: nurse_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'responds with 401 for an invalid token' do
        patch "/api/v1/consents/#{consent.id}", params: { granted: false }, headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'responds with 401 when Authorization header is absent' do
        patch "/api/v1/consents/#{consent.id}", params: { granted: false }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================================================
  # DELETE /api/v1/consents/:id
  # ===========================================================================
  describe 'DELETE #destroy' do
    let!(:consent) { create(:consent) }

    context 'when authenticated as admin' do
      it 'responds with 200 ok' do
        delete "/api/v1/consents/#{consent.id}", headers: admin_headers
        expect(response).to have_http_status(:ok)
      end

      it 'destroys the Consent record' do
        expect {
          delete "/api/v1/consents/#{consent.id}", headers: admin_headers
        }.to change(Consent, :count).by(-1)
      end

      it 'returns a confirmation message' do
        delete "/api/v1/consents/#{consent.id}", headers: admin_headers
        expect(json_body['message']).to be_present
      end

      context 'when consent does not exist' do
        it 'responds with 404 not found' do
          delete '/api/v1/consents/0', headers: admin_headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when authenticated as doctor' do
      it 'responds with 200 ok' do
        delete "/api/v1/consents/#{consent.id}", headers: doctor_headers
        expect(response).to have_http_status(:ok)
      end

      it 'destroys the Consent record' do
        expect {
          delete "/api/v1/consents/#{consent.id}", headers: doctor_headers
        }.to change(Consent, :count).by(-1)   # ← .to not .not_to
      end
    end

    context 'when authenticated as nurse' do
      it 'responds with 403 forbidden' do
        delete "/api/v1/consents/#{consent.id}", headers: nurse_headers
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not destroy the Consent record' do
        expect {
          delete "/api/v1/consents/#{consent.id}", headers: nurse_headers
        }.not_to change(Consent, :count)
      end
    end

    context 'when unauthenticated' do
      it 'responds with 401 for an invalid token' do
        delete "/api/v1/consents/#{consent.id}", headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'responds with 401 when Authorization header is absent' do
        delete "/api/v1/consents/#{consent.id}"
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not destroy the Consent record' do
        expect {
          delete "/api/v1/consents/#{consent.id}", headers: invalid_headers
        }.not_to change(Consent, :count)
      end
    end
  end
end
