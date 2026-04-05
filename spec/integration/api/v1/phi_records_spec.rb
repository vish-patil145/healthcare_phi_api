# spec/integration/api/v1/phi_records_spec.rb
require 'swagger_helper'

RSpec.describe 'api/v1/phi_records', type: :request do
  let(:admin)  { create(:user, role: :admin) }
  let(:doctor) { create(:user, role: :doctor) }
  let(:nurse)  { create(:user, role: :nurse) }

  let(:admin_token)  { JwtService.encode({ user_id: admin.id }) }
  let(:doctor_token) { JwtService.encode({ user_id: doctor.id }) }
  let(:nurse_token)  { JwtService.encode({ user_id: nurse.id }) }

  # ===========================================================================
  # POST /api/v1/phi_records
  # ===========================================================================
  path '/api/v1/phi_records' do
    post 'Create a PHI record' do
      tags     'PHI Records'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: 'Idempotency-Key', in: :header, type: :string, required: true
      parameter name: :phi_record, in: :body, schema: {
        '$ref' => '#/components/schemas/PhiRecordInput'
      }

      # ── 201 Created ────────────────────────────────────────────────────────
      response '201', 'doctor creates a PHI record' do
        let(:Authorization)     { "Bearer #{doctor_token}" }
        let(:'Idempotency-Key') { SecureRandom.uuid }
        let(:phi_record) do
          {
            patient_id:  create(:patient).id,
            record_type: 'general',
            data: {
              diagnosis:    'Hypertension',
              symptoms:     [ 'headache' ],
              doctor_notes: 'Monitor BP'
            }
          }
        end
        schema '$ref' => '#/components/schemas/PhiRecord'
        run_test!
      end

      response '201', 'admin creates a PHI record' do
        let(:Authorization)     { "Bearer #{admin_token}" }
        let(:'Idempotency-Key') { SecureRandom.uuid }
        let(:phi_record) do
          {
            patient_id:  create(:patient).id,
            record_type: 'general',
            data:        { diagnosis: 'Flu' }
          }
        end
        schema '$ref' => '#/components/schemas/PhiRecord'
        run_test!
      end

      # ── 200 Idempotent ─────────────────────────────────────────────────────
      response '200', 'idempotent — duplicate key returns existing record' do
        let(:existing)          { create(:phi_record, created_by: doctor) }
        let(:Authorization)     { "Bearer #{doctor_token}" }
        let(:'Idempotency-Key') { existing.request_id }
        let(:phi_record)        { { patient_id: existing.patient_id, data: {} } }
        run_test!
      end

      # ── 403 Forbidden ──────────────────────────────────────────────────────
      response '403', 'nurse is forbidden from creating' do
        let(:Authorization)     { "Bearer #{nurse_token}" }
        let(:'Idempotency-Key') { SecureRandom.uuid }
        let(:phi_record)        { { patient_id: create(:patient).id, data: {} } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 422 Validation failed ──────────────────────────────────────────────
      response '422', 'validation failed — missing patient_id' do
        let(:Authorization)     { "Bearer #{doctor_token}" }
        let(:'Idempotency-Key') { SecureRandom.uuid }
        let(:phi_record)        { { data: { diagnosis: 'X' } } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 Unauthorized ───────────────────────────────────────────────────
      response '401', 'invalid token' do
        let(:Authorization)     { 'Bearer invalid_token' }
        let(:'Idempotency-Key') { SecureRandom.uuid }
        let(:phi_record)        { { patient_id: 1, data: {} } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '401', 'missing authorization header' do
        let(:Authorization)     { '' }
        let(:'Idempotency-Key') { SecureRandom.uuid }
        let(:phi_record)        { { patient_id: 1, data: {} } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    # =========================================================================
    # GET /api/v1/phi_records
    # =========================================================================
    get 'List PHI records' do
      tags     'PHI Records'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :status,     in: :query, type: :string,  required: false
      parameter name: :patient_id, in: :query, type: :integer, required: false
      parameter name: :page,       in: :query, type: :integer, required: false
      parameter name: :per_page,   in: :query, type: :integer, required: false

      # ── 200 OK ─────────────────────────────────────────────────────────────
      response '200', 'doctor lists PHI records' do
        let(:Authorization) { "Bearer #{doctor_token}" }
        let(:status)        { nil }
        let(:patient_id)    { nil }
        let(:page)          { 1 }
        let(:per_page)      { 10 }

        before { create_list(:phi_record, 3, created_by: doctor) }

        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/PhiRecord' } },
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

      response '200', 'admin lists PHI records' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:status)        { nil }
        let(:patient_id)    { nil }
        let(:page)          { 1 }
        let(:per_page)      { 10 }

        before { create_list(:phi_record, 2, created_by: doctor) }

        schema type: :object,
               properties: {
                 data: { type: :array },
                 meta: { type: :object }
               }
        run_test!
      end

      # ── 403 Forbidden ──────────────────────────────────────────────────────
      response '403', 'nurse is forbidden from listing' do
        let(:Authorization) { "Bearer #{nurse_token}" }
        let(:status)        { nil }
        let(:patient_id)    { nil }
        let(:page)          { 1 }
        let(:per_page)      { 10 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 Unauthorized ───────────────────────────────────────────────────
      response '401', 'invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:status)        { nil }
        let(:patient_id)    { nil }
        let(:page)          { 1 }
        let(:per_page)      { 10 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/phi_records/:id
  # ===========================================================================
  path '/api/v1/phi_records/{id}' do
    get 'Show a PHI record' do
      tags     'PHI Records'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :id, in: :path, type: :integer, required: true

      # ── 200 OK — doctor ────────────────────────────────────────────────────
      response '200', 'doctor retrieves full record' do
        let(:record)        { create(:phi_record, created_by: doctor) }
        let(:id)            { record.id }
        let(:Authorization) { "Bearer #{doctor_token}" }
        schema '$ref' => '#/components/schemas/PhiRecord'
        run_test!
      end

      # ── 200 OK — admin ─────────────────────────────────────────────────────
      response '200', 'admin retrieves full record' do
        let(:record)        { create(:phi_record, created_by: doctor) }
        let(:id)            { record.id }
        let(:Authorization) { "Bearer #{admin_token}" }
        schema '$ref' => '#/components/schemas/PhiRecord'
        run_test!
      end

      # ── 200 OK — nurse with consent ────────────────────────────────────────
      response '200', 'nurse with consent retrieves masked record' do
        let(:record)        { create(:phi_record, created_by: doctor) }
        let(:id)            { record.id }
        let(:Authorization) { "Bearer #{nurse_token}" }

        before do
          create(:consent,
                 patient_id: record.patient_id,
                 granted_to: nurse.email,
                 granted:    true)
        end

        schema '$ref' => '#/components/schemas/PhiRecord'
        run_test!
      end

      # ── 403 Forbidden — nurse without consent ──────────────────────────────
      response '403', 'nurse without consent is forbidden' do
        let(:record)        { create(:phi_record, created_by: doctor) }
        let(:id)            { record.id }
        let(:Authorization) { "Bearer #{nurse_token}" }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 404 Not Found ──────────────────────────────────────────────────────
      response '404', 'record not found' do
        let(:id)            { 0 }
        let(:Authorization) { "Bearer #{doctor_token}" }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 Unauthorized ───────────────────────────────────────────────────
      response '401', 'unauthenticated request' do
        let(:id)            { create(:phi_record, created_by: doctor).id }
        let(:Authorization) { 'Bearer bad_token' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
