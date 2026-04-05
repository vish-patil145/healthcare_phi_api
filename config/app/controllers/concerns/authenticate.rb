# app/controllers/concerns/authenticate.rb
module Authenticate
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
  end

  def authenticate_request
    token = request.headers["Authorization"]&.split(" ")&.last
    decoded = JwtService.decode(token)
    @current_user = User.find(decoded["user_id"])
  rescue
    render json: { error: "Unauthorized" }, status: 401
  end
end
