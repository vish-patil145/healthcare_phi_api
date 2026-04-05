# spec/integration/api/v1/patients_spec.rb
require 'swagger_helper'

RSpec.describe 'api/v1/patients', type: :request do
  let(:admin)  { create(:user, role: :admin) }
  let(:doctor) { create(:user, role: :doctor) }
  let(:nurse)  { create(:user, role: :nurse) }

  let(:admin_token)  { JwtService.encode({ user_id: admin.id }) }
  let(:doctor_token) { JwtService.encode({ user_id: doctor.id }) }
  let(:nurse_token)  { JwtService.encode({ user_id: nurse.id }) }

  # ===========================================================================
  # POST /api/v1/patients
  # ===========================================================================
  path '/api/v1/patients' do
    post 'Create a patient' do
      tags     'Patients'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :patient, in: :body, schema: {
        '$ref' => '#/components/schemas/PatientInput'
      }

      # ── 201 ────────────────────────────────────────────────────────────────
      response '201', 'admin creates a patient' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:patient) { { name: 'Jane Doe', age: 30, gender: 'female', email: 'jane.doe@example.com' } }
        schema '$ref' => '#/components/schemas/Patient'
        run_test!
      end

      response '201', 'doctor creates a patient' do
        let(:Authorization) { "Bearer #{doctor_token}" }
        let(:patient) { { name: 'John Smith', age: 45, gender: 'male', email: 'john.smith@example.com' } }
        schema '$ref' => '#/components/schemas/Patient'
        run_test!
      end

      # ── 403 ────────────────────────────────────────────────────────────────
      response '403', 'nurse is forbidden from creating a patient' do
        let(:Authorization) { "Bearer #{nurse_token}" }
        let(:patient) { { name: 'Alice', age: 28, gender: 'female' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 422 ────────────────────────────────────────────────────────────────
      response '422', 'validation failed — blank name' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:patient) { { name: '', age: 30, gender: 'female' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '422', 'validation failed — empty body' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:patient) { {} }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 ────────────────────────────────────────────────────────────────
      response '401', 'invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:patient) { { name: 'Jane', age: 25, gender: 'female' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '401', 'missing authorization header' do
        let(:Authorization) { '' }
        let(:patient) { { name: 'Jane', age: 25, gender: 'female' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    # =========================================================================
    # GET /api/v1/patients
    # =========================================================================
    get 'List patients' do
      tags     'Patients'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :name,     in: :query, type: :string,  required: false, description: 'Filter by name (ILIKE)'
      parameter name: :age,      in: :query, type: :integer, required: false, description: 'Filter by exact age'
      parameter name: :page,     in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Records per page (default 10)'

      # ── 200 ────────────────────────────────────────────────────────────────
      response '200', 'admin lists patients' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:name) { nil }; let(:age) { nil }
        let(:page) { 1 };   let(:per_page) { 10 }

        before { create_list(:patient, 3) }

        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Patient' } },
                 meta: {
                   type: :object,
                   required: %w[current_page total_pages],
                   properties: {
                     current_page: { type: :integer },
                     total_pages:  { type: :integer }
                   }
                 }
               }
        run_test!
      end

      response '200', 'doctor lists patients' do
        let(:Authorization) { "Bearer #{doctor_token}" }
        let(:name) { nil }; let(:age) { nil }
        let(:page) { 1 };   let(:per_page) { 10 }

        before { create(:patient) }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Patient' } },
                 meta: { type: :object }
               }
        run_test!
      end

      # ── 403 ────────────────────────────────────────────────────────────────
      response '403', 'nurse is forbidden from listing patients' do
        let(:Authorization) { "Bearer #{nurse_token}" }
        let(:name) { nil }; let(:age) { nil }
        let(:page) { 1 };   let(:per_page) { 10 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 ────────────────────────────────────────────────────────────────
      response '401', 'invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:name) { nil }; let(:age) { nil }
        let(:page) { 1 };   let(:per_page) { 10 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/patients/:id
  # ===========================================================================
  path '/api/v1/patients/{id}' do
    get 'Show a patient' do
      tags     'Patients'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :id, in: :path, type: :integer, required: true

      # ── 200 ────────────────────────────────────────────────────────────────
      response '200', 'admin retrieves a patient' do
        let(:record)        { create(:patient) }
        let(:id)            { record.id }
        let(:Authorization) { "Bearer #{admin_token}" }
        schema '$ref' => '#/components/schemas/Patient'
        run_test!
      end

      response '200', 'doctor retrieves a patient' do
        let(:record)        { create(:patient) }
        let(:id)            { record.id }
        let(:Authorization) { "Bearer #{doctor_token}" }
        schema '$ref' => '#/components/schemas/Patient'
        run_test!
      end

      response '200', 'nurse retrieves a patient' do
        let(:record)        { create(:patient) }
        let(:id)            { record.id }
        let(:Authorization) { "Bearer #{nurse_token}" }
        schema '$ref' => '#/components/schemas/Patient'
        run_test!
      end

      # ── 404 ────────────────────────────────────────────────────────────────
      response '404', 'patient not found' do
        let(:id)            { 0 }
        let(:Authorization) { "Bearer #{admin_token}" }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 ────────────────────────────────────────────────────────────────
      response '401', 'unauthenticated request' do
        let(:id)            { create(:patient).id }
        let(:Authorization) { 'Bearer bad_token' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
