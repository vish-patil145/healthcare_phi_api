# spec/integration/api/v1/consents_spec.rb
require 'swagger_helper'

RSpec.describe 'api/v1/consents', type: :request do
  let(:admin)  { create(:user, role: :admin) }
  let(:doctor) { create(:user, role: :doctor) }
  let(:nurse)  { create(:user, role: :nurse) }

  let(:admin_token)  { JwtService.encode({ user_id: admin.id }) }
  let(:doctor_token) { JwtService.encode({ user_id: doctor.id }) }
  let(:nurse_token)  { JwtService.encode({ user_id: nurse.id }) }

  let(:patient) { create(:patient) }

  # ===========================================================================
  # POST /api/v1/consents
  # ===========================================================================
  path '/api/v1/consents' do
    post 'Create or update a consent' do
      tags     'Consents'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :consent, in: :body, schema: {
        '$ref' => '#/components/schemas/ConsentInput'
      }

      # ── 201 ────────────────────────────────────────────────────────────────
      response '201', 'admin creates a consent' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:consent) do
          { patient_id: patient.id, granted_to: nurse.email, granted: true }
        end
        schema '$ref' => '#/components/schemas/Consent'
        run_test!
      end

      response '201', 'doctor creates a consent' do
        let(:Authorization) { "Bearer #{doctor_token}" }
        let(:consent) do
          { patient_id: patient.id, granted_to: nurse.email, granted: true }
        end
        schema '$ref' => '#/components/schemas/Consent'
        run_test!
      end

      # ── 200 ────────────────────────────────────────────────────────────────
      response '200', 'updates existing consent (idempotent)' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let!(:existing_consent) do
          create(:consent, patient_id: patient.id, granted_to: nurse.email, granted: true)
        end
        let(:consent) do
          { patient_id: patient.id, granted_to: nurse.email, granted: false }
        end
        schema '$ref' => '#/components/schemas/Consent'
        run_test!
      end

      # ── 422 ────────────────────────────────────────────────────────────────
      response '422', 'validation failed — missing patient_id' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:consent) { { granted_to: nurse.email, granted: true } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '422', 'validation failed — missing granted_to' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:consent) { { patient_id: patient.id, granted: true } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 ────────────────────────────────────────────────────────────────
      response '401', 'invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:consent) do
          { patient_id: patient.id, granted_to: nurse.email, granted: true }
        end
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '401', 'missing authorization header' do
        let(:Authorization) { '' }
        let(:consent) do
          { patient_id: patient.id, granted_to: nurse.email, granted: true }
        end
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    # =========================================================================
    # GET /api/v1/consents
    # =========================================================================
    get 'List consents' do
      tags     'Consents'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :patient_id, in: :query, type: :integer, required: false, description: 'Filter by patient'
      parameter name: :granted_to, in: :query, type: :string,  required: false, description: 'Filter by grantee email'
      parameter name: :granted,    in: :query, type: :boolean, required: false, description: 'Filter by granted status'
      parameter name: :page,       in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page,   in: :query, type: :integer, required: false, description: 'Records per page (default 10)'

      # ── 200 ────────────────────────────────────────────────────────────────
      response '200', 'admin lists all consents' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:patient_id) { nil }; let(:granted_to) { nil }
        let(:granted)    { nil }
        let(:page)       { 1 };   let(:per_page)   { 10 }

        before { create_list(:consent, 3, patient: patient) }

        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Consent' } },
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

      response '200', 'filters consents by patient_id' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:other_patient) { create(:patient) }
        let(:patient_id)    { patient.id }
        let(:granted_to)    { nil }; let(:granted) { nil }
        let(:page)          { 1 };   let(:per_page) { 10 }

        before do
          create(:consent, patient: patient)
          create(:consent, patient: other_patient)
        end

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Consent' } },
                 meta: { type: :object }
               }
        run_test!
      end

      response '200', 'filters consents by granted_to' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:patient_id)    { nil }; let(:granted) { nil }
        let(:granted_to)    { nurse.email }
        let(:page)          { 1 };   let(:per_page) { 10 }

        before { create(:consent, patient: patient, granted_to: nurse.email) }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Consent' } },
                 meta: { type: :object }
               }
        run_test!
      end

      response '200', 'filters consents by granted status' do
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:patient_id)    { nil }; let(:granted_to) { nil }
        let(:granted)       { true }
        let(:page)          { 1 };   let(:per_page)   { 10 }

        before do
          create(:consent, patient: patient, granted: true)
          create(:consent, patient: patient, granted: false)
        end

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Consent' } },
                 meta: { type: :object }
               }
        run_test!
      end

      # ── 401 ────────────────────────────────────────────────────────────────
      response '401', 'invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:patient_id) { nil }; let(:granted_to) { nil }
        let(:granted)    { nil }
        let(:page)       { 1 };   let(:per_page)   { 10 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/consents/:id
  # ===========================================================================
  path '/api/v1/consents/{id}' do
    get 'Show a consent' do
      tags     'Consents'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :id, in: :path, type: :integer, required: true

      # ── 200 ────────────────────────────────────────────────────────────────
      response '200', 'admin retrieves a consent' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{admin_token}" }
        schema '$ref' => '#/components/schemas/Consent'
        run_test!
      end

      response '200', 'doctor retrieves a consent' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{doctor_token}" }
        schema '$ref' => '#/components/schemas/Consent'
        run_test!
      end

      response '200', 'nurse retrieves a consent granted to them' do
        let(:consent_record) { create(:consent, patient: patient, granted_to: nurse.email, granted: true) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{nurse_token}" }
        schema '$ref' => '#/components/schemas/Consent'
        run_test!
      end

      # ── 403 ────────────────────────────────────────────────────────────────
      response '403', 'nurse is forbidden from viewing a consent not granted to them' do
        let(:consent_record) { create(:consent, patient: patient, granted_to: 'other@hospital.com', granted: true) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{nurse_token}" }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 404 ────────────────────────────────────────────────────────────────
      response '404', 'consent not found' do
        let(:id)            { 0 }
        let(:Authorization) { "Bearer #{admin_token}" }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 ────────────────────────────────────────────────────────────────
      response '401', 'unauthenticated request' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { 'Bearer bad_token' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  # ===========================================================================
  # PATCH /api/v1/consents/:id
  # ===========================================================================
  path '/api/v1/consents/{id}' do
    patch 'Update a consent' do
      tags     'Consents'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :consent, in: :body, schema: {
        '$ref' => '#/components/schemas/ConsentInput'
      }

      # ── 200 ────────────────────────────────────────────────────────────────
      response '200', 'admin updates a consent' do
        let(:consent_record) { create(:consent, patient: patient, granted: true) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{admin_token}" }
        let(:consent)        { { granted: false } }
        schema '$ref' => '#/components/schemas/Consent'
        run_test!
      end

      response '200', 'doctor updates a consent' do
        let(:consent_record) { create(:consent, patient: patient, granted: false) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{doctor_token}" }
        let(:consent)        { { granted: true } }
        schema '$ref' => '#/components/schemas/Consent'
        run_test!
      end

      # ── 403 ────────────────────────────────────────────────────────────────
      response '403', 'nurse is forbidden from updating a consent' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{nurse_token}" }
        let(:consent)        { { granted: true } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 422 ────────────────────────────────────────────────────────────────
      response '422', 'validation failed — invalid params' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{admin_token}" }
        let(:consent)        { { patient_id: nil } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 404 ────────────────────────────────────────────────────────────────
      response '404', 'consent not found' do
        let(:id)            { 0 }
        let(:Authorization) { "Bearer #{admin_token}" }
        let(:consent)       { { granted: true } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 ────────────────────────────────────────────────────────────────
      response '401', 'unauthenticated request' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { 'Bearer bad_token' }
        let(:consent)        { { granted: true } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  # ===========================================================================
  # DELETE /api/v1/consents/:id
  # ===========================================================================
  path '/api/v1/consents/{id}' do
    delete 'Revoke a consent' do
      tags     'Consents'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      parameter name: :id, in: :path, type: :integer, required: true

      # ── 200 ────────────────────────────────────────────────────────────────
      # Note: using consent_record (not record) to avoid conflict with rswag internals
      response '200', 'admin revokes a consent' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{admin_token}" }
        schema type: :object,
               required: %w[message],
               properties: {
                 message: { type: :string, example: 'Consent revoked' }
               }
        run_test!
      end

      response '200', 'doctor revokes a consent' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{doctor_token}" }
        schema type: :object,
               required: %w[message],
               properties: {
                 message: { type: :string, example: 'Consent revoked' }
               }
        run_test!
      end

      # ── 403 ────────────────────────────────────────────────────────────────
      response '403', 'nurse is forbidden from revoking a consent' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { "Bearer #{nurse_token}" }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 404 ────────────────────────────────────────────────────────────────
      response '404', 'consent not found' do
        let(:id)            { 0 }
        let(:Authorization) { "Bearer #{admin_token}" }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      # ── 401 ────────────────────────────────────────────────────────────────
      response '401', 'unauthenticated request' do
        let(:consent_record) { create(:consent, patient: patient) }
        let(:id)             { consent_record.id }
        let(:Authorization)  { 'Bearer bad_token' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
