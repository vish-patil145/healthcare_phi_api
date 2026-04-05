class ApplicationController < ActionController::API
  include Pundit::Authorization
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  before_action :authenticate_request

  attr_reader :current_user

  # ── Global error handlers ──────────────────────────────────────────────────
  rescue_from ActiveRecord::RecordNotFound,       with: :not_found
  rescue_from ActiveRecord::RecordInvalid,        with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private
  def user_not_authorized
    render json: { error: "Forbidden" }, status: :forbidden
  end
  # 🔐 Authenticate user from JWT
  def authenticate_request
    token = extract_token_from_header
    decoded = JwtService.decode(token)

    if decoded
      @current_user = User.find_by(id: decoded["user_id"])
      render_unauthorized unless @current_user
    else
      render_unauthorized
    end
  end

  # ── Token extractor ────────────────────────────────────────────────────────
  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  # ── Error renderers ────────────────────────────────────────────────────────
  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def render_forbidden
    render json: { error: "Forbidden" }, status: :forbidden
  end

  def not_found(e)
    render json: { error: e.message }, status: :not_found
  end

  def unprocessable_entity(e)
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def bad_request(e)
    render json: { error: e.message }, status: :bad_request
  end
end
