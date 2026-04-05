# spec/integration/api/v1/auth_spec.rb
require 'swagger_helper'

RSpec.describe 'api/v1/auth', type: :request do
  path '/api/v1/auth' do
    post 'Generate JWT token (Login)' do
      tags        'Authentication'
      consumes    'application/json'
      produces    'application/json'
      description 'Authenticates a user with email and password. Returns a signed JWT token on success.'

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email:    { type: :string, example: 'admin@hospital.com' },
          password: { type: :string, example: 'password123', format: 'password' }
        },
        required: %w[email password]
      }

      # ── 200 Success ────────────────────────────────────────────────────────
      response '200', 'login successful' do
        schema type: :object,
               required: %w[token],
               properties: {
                 token: { type: :string, example: 'eyJhbGciOiJIUzI1NiJ9...' }
               }

        let(:user)        { create(:user, password: 'secret123') }
        let(:credentials) { { email: user.email, password: 'secret123' } }

        run_test!
      end

      # ── 401 Wrong password ─────────────────────────────────────────────────
      response '401', 'invalid credentials — wrong password' do
        schema type: :object,
               required: %w[error],
               properties: {
                 error: { type: :string, example: 'Invalid' }
               }

        let(:user)        { create(:user, password: 'correct_password') }
        let(:credentials) { { email: user.email, password: 'wrong_password' } }

        run_test!
      end

      # ── 401 Non-existent user ──────────────────────────────────────────────
      response '401', 'invalid credentials — email not found' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Invalid' }
               }

        let(:credentials) { { email: 'nobody@example.com', password: 'password123' } }

        run_test!
      end

      # ── 401 Missing params ─────────────────────────────────────────────────
      response '401', 'missing email or password' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Invalid' }
               }

        let(:credentials) { { email: '', password: '' } }

        run_test!
      end
    end
  end
end
