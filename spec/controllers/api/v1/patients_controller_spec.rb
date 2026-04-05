# spec/controllers/api/v1/patients_controller_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::PatientsController, type: :request do
  let(:admin)  { create(:user, role: :admin) }
  let(:doctor) { create(:user, role: :doctor) }
  let(:nurse)  { create(:user, role: :nurse) }

  let(:admin_headers)   { auth_headers(admin) }
  let(:doctor_headers)  { auth_headers(doctor) }
  let(:nurse_headers)   { auth_headers(nurse) }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_token' } }

  def json_body
    JSON.parse(response.body)
  end

  # ===========================================================================
  # POST /api/v1/patients
  # ===========================================================================
  describe 'POST #create' do
    let(:valid_params)      { { name: 'Jane Doe', age: 30, gender: 'female', email: 'jane.doe@example.com' } }
    let(:blank_name_params) { { name: '', age: 30, gender: 'female' } }
    let(:empty_params)      { {} }

    context 'when authenticated as admin' do
      context 'with valid params' do
        it 'responds with 201 created' do
          post '/api/v1/patients', params: valid_params, headers: admin_headers
          expect(response).to have_http_status(:created)
        end

        it 'creates a new Patient record' do
          expect {
            post '/api/v1/patients', params: valid_params, headers: admin_headers
          }.to change(Patient, :count).by(1)
        end

        it 'returns the patient name' do
          post '/api/v1/patients', params: valid_params, headers: admin_headers
          expect(json_body['name']).to eq('Jane Doe')
        end

        it 'returns the patient age' do
          post '/api/v1/patients', params: valid_params, headers: admin_headers
          expect(json_body['age']).to eq(30)
        end

        it 'returns the patient gender' do
          post '/api/v1/patients', params: valid_params, headers: admin_headers
          expect(json_body['gender']).to eq('female')
        end

        it 'returns a non-nil id' do
          post '/api/v1/patients', params: valid_params, headers: admin_headers
          expect(json_body['id']).to be_present
        end
      end

      context 'with blank name' do
        it 'responds with 422 unprocessable entity' do
          post '/api/v1/patients', params: blank_name_params, headers: admin_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'returns an errors array' do
          post '/api/v1/patients', params: blank_name_params, headers: admin_headers
          expect(json_body['errors']).to be_an(Array).and be_present
        end

        it 'includes a name-related error message' do
          post '/api/v1/patients', params: blank_name_params, headers: admin_headers
          expect(json_body['errors'].join).to match(/name/i)
        end

        it 'does not create a Patient record' do
          expect {
            post '/api/v1/patients', params: blank_name_params, headers: admin_headers
          }.not_to change(Patient, :count)
        end
      end

      context 'with empty params' do
        it 'responds with 422 unprocessable entity' do
          post '/api/v1/patients', params: empty_params, headers: admin_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'does not create a Patient record' do
          expect {
            post '/api/v1/patients', params: empty_params, headers: admin_headers
          }.not_to change(Patient, :count)
        end
      end
    end

    context 'when authenticated as doctor' do
      it 'responds with 201 created' do
        post '/api/v1/patients', params: valid_params, headers: doctor_headers
        expect(response).to have_http_status(:created)
      end

      it 'creates a new Patient record' do
        expect {
          post '/api/v1/patients', params: valid_params, headers: doctor_headers
        }.to change(Patient, :count).by(1)
      end
    end

    context 'when authenticated as nurse' do
      it 'responds with 403 forbidden' do
        post '/api/v1/patients', params: valid_params, headers: nurse_headers
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not create a Patient record' do
        expect {
          post '/api/v1/patients', params: valid_params, headers: nurse_headers
        }.not_to change(Patient, :count)
      end
    end

    context 'when unauthenticated' do
      it 'responds with 401 for an invalid token' do
        post '/api/v1/patients', params: valid_params, headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'responds with 401 when Authorization header is absent' do
        post '/api/v1/patients', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create a Patient record' do
        expect {
          post '/api/v1/patients', params: valid_params, headers: invalid_headers
        }.not_to change(Patient, :count)
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/patients
  # ===========================================================================
  describe 'GET #index' do
    context 'when authenticated as admin' do
      it 'responds with 200 ok' do
        get '/api/v1/patients', headers: admin_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns a data array' do
        get '/api/v1/patients', headers: admin_headers
        expect(json_body['data']).to be_an(Array)
      end

      context 'returns all patients' do
        before { create_list(:patient, 5) }

        it 'returns exactly 5 patients' do
          get '/api/v1/patients', headers: admin_headers
          expect(json_body['data'].length).to eq(5)
        end

        it 'returns current_page in meta' do
          get '/api/v1/patients', headers: admin_headers
          expect(json_body['meta']['current_page']).to eq(1)
        end

        it 'returns total_pages in meta' do
          get '/api/v1/patients', headers: admin_headers
          expect(json_body['meta']['total_pages']).to be >= 1
        end
      end

      context 'with name filter' do
        before do
          create(:patient, name: 'Jane Doe')
          create(:patient, name: 'JANE Smith')
          create(:patient, name: 'Bob Builder')
        end

        it 'matches case-insensitively and excludes non-matches' do
          get '/api/v1/patients', params: { name: 'jane' }, headers: admin_headers
          names = json_body['data'].map { |p| p['name'].downcase }
          expect(names).to all(include('jane'))
        end

        it 'returns empty data when no names match' do
          get '/api/v1/patients', params: { name: 'zzznomatch' }, headers: admin_headers
          expect(json_body['data']).to be_empty
        end
      end

      context 'with age filter' do
        before do
          create(:patient, age: 30)
          create(:patient, age: 30)
          create(:patient, age: 55)
        end

        it 'returns only patients of that exact age' do
          get '/api/v1/patients', params: { age: 30 }, headers: admin_headers
          ages = json_body['data'].map { |p| p['age'] }
          expect(ages).to all(eq(30))
        end

        it 'returns empty data when no age matches' do
          get '/api/v1/patients', params: { age: 99 }, headers: admin_headers
          expect(json_body['data']).to be_empty
        end
      end

      context 'with pagination' do
        before { create_list(:patient, 5) }

        it 'returns the correct page slice' do
          get '/api/v1/patients', params: { page: 2, per_page: 2 }, headers: admin_headers
          expect(json_body['data'].length).to eq(2)
        end

        it 'reflects current_page correctly in meta' do
          get '/api/v1/patients', params: { page: 2, per_page: 2 }, headers: admin_headers
          expect(json_body['meta']['current_page']).to eq(2)
        end

        it 'calculates total_pages correctly' do
          get '/api/v1/patients', params: { page: 1, per_page: 2 }, headers: admin_headers
          expect(json_body['meta']['total_pages']).to eq(3)
        end

        it 'defaults to page 1 when page param is omitted' do
          get '/api/v1/patients', headers: admin_headers
          expect(json_body['meta']['current_page']).to eq(1)
        end
      end
    end

    context 'when authenticated as doctor' do
      it 'responds with 200 ok' do
        get '/api/v1/patients', headers: doctor_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as nurse' do
      it 'responds with 403 forbidden' do
        get '/api/v1/patients', headers: nurse_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'responds with 401 for an invalid token' do
        get '/api/v1/patients', headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'responds with 401 when Authorization header is absent' do
        get '/api/v1/patients'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/patients/:id
  # ===========================================================================
  describe 'GET #show' do
    let(:patient) { create(:patient) }

    context 'when authenticated as admin' do
      it 'responds with 200 ok' do
        get "/api/v1/patients/#{patient.id}", headers: admin_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns the correct patient id' do
        get "/api/v1/patients/#{patient.id}", headers: admin_headers
        expect(json_body['id']).to eq(patient.id)
      end

      it 'returns the correct patient name' do
        get "/api/v1/patients/#{patient.id}", headers: admin_headers
        expect(json_body['name']).to eq(patient.name)
      end

      it 'returns the correct patient age' do
        get "/api/v1/patients/#{patient.id}", headers: admin_headers
        expect(json_body['age']).to eq(patient.age)
      end

      it 'returns the correct patient gender' do
        get "/api/v1/patients/#{patient.id}", headers: admin_headers
        expect(json_body['gender']).to eq(patient.gender)
      end
    end

    context 'when authenticated as doctor' do
      it 'responds with 200 ok' do
        get "/api/v1/patients/#{patient.id}", headers: doctor_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as nurse' do
      it 'responds with 200 ok — nurse can view individual patients' do
        get "/api/v1/patients/#{patient.id}", headers: nurse_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when patient does not exist' do
      it 'responds with 404 not found' do
        get '/api/v1/patients/0', headers: admin_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error message' do
        get '/api/v1/patients/0', headers: admin_headers
        expect(json_body['error']).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'responds with 401 for an invalid token' do
        get "/api/v1/patients/#{patient.id}", headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'responds with 401 when Authorization header is absent' do
        get "/api/v1/patients/#{patient.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
