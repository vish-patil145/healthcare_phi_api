class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_request, only: [ :create ]
  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      token = JwtService.encode({ user_id: user.id })
      render json: { token: token }
    else
      render json: { error: "Invalid" }, status: 401
    end
  end
end
