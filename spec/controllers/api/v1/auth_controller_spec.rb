# spec/controllers/api/v1/auth_controller_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::AuthController, type: :request do
  let(:password) { 'password123' }
  let(:user)     { create(:user, password: password) }

  def json_body
    JSON.parse(response.body)
  end

  # ===========================================================================
  # POST /api/v1/auth
  # ===========================================================================
  describe 'POST #create' do
    let(:valid_params)            { { email: user.email, password: password } }
    let(:wrong_password_params)   { { email: user.email, password: 'wrongpassword' } }
    let(:nonexistent_email_params) { { email: 'nobody@example.com', password: password } }
    let(:empty_params)            { {} }

    context 'with valid credentials' do
      it 'responds with 200 ok' do
        post '/api/v1/auth', params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it 'returns a token' do
        post '/api/v1/auth', params: valid_params
        expect(json_body['token']).to be_present
      end

      it 'returns a string token' do
        post '/api/v1/auth', params: valid_params
        expect(json_body['token']).to be_a(String)
      end

      it 'does not return an error' do
        post '/api/v1/auth', params: valid_params
        expect(json_body['error']).to be_nil
      end
    end

    context 'with wrong password' do
      it 'responds with 401 unauthorized' do
        post '/api/v1/auth', params: wrong_password_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns an error message' do
        post '/api/v1/auth', params: wrong_password_params
        expect(json_body['error']).to be_present
      end

      it 'does not return a token' do
        post '/api/v1/auth', params: wrong_password_params
        expect(json_body['token']).to be_nil
      end
    end

    context 'with a nonexistent email' do
      it 'responds with 401 unauthorized' do
        post '/api/v1/auth', params: nonexistent_email_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns an error message' do
        post '/api/v1/auth', params: nonexistent_email_params
        expect(json_body['error']).to be_present
      end

      it 'does not return a token' do
        post '/api/v1/auth', params: nonexistent_email_params
        expect(json_body['token']).to be_nil
      end
    end

    context 'with empty params' do
      it 'responds with 401 unauthorized' do
        post '/api/v1/auth', params: empty_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns an error message' do
        post '/api/v1/auth', params: empty_params
        expect(json_body['error']).to be_present
      end

      it 'does not return a token' do
        post '/api/v1/auth', params: empty_params
        expect(json_body['token']).to be_nil
      end
    end
  end
end
