# spec/controllers/application_controller_spec.rb
#
# ApplicationController is abstract — we test it through an anonymous concrete
# subclass that exposes all the private behaviour via a single test endpoint.

RSpec.describe ApplicationController, type: :controller do
  # ── Anonymous concrete subclass ────────────────────────────────────────────
  controller do
    # Skips authentication so we can test it independently
    skip_before_action :authenticate_request, only: [ :public_action ]

    def index
      render json: { message: "ok" }, status: :ok
    end

    def public_action
      render json: { message: "public" }, status: :ok
    end

    def trigger_not_found
      raise ActiveRecord::RecordNotFound, "Couldn't find Patient with id=99"
    end

    def trigger_record_invalid
      patient = Patient.new
      patient.save!
    rescue ActiveRecord::RecordInvalid => e
      raise e
    end

    def trigger_parameter_missing
      raise ActionController::ParameterMissing, :email
    end

    def trigger_not_authorized
      raise Pundit::NotAuthorizedError
    end

    def trigger_render_forbidden
      render_forbidden
    end
  end

  let(:user) { instance_double("User", id: 1) }
  let(:token) { "valid.jwt.token" }
  let(:auth_header) { "Bearer #{token}" }

  before do
    routes.draw do
      get  "index"                  => "anonymous#index"
      get  "public_action"          => "anonymous#public_action"
      get  "trigger_not_found"      => "anonymous#trigger_not_found"
      get  "trigger_record_invalid" => "anonymous#trigger_record_invalid"
      get  "trigger_parameter_missing" => "anonymous#trigger_parameter_missing"
      get  "trigger_not_authorized"    => "anonymous#trigger_not_authorized"
      get  "trigger_render_forbidden"  => "anonymous#trigger_render_forbidden"
    end
  end

  # ─── authenticate_request ──────────────────────────────────────────────────

  describe "#authenticate_request" do
    context "with a valid JWT and a matching user" do
      before do
        request.headers["Authorization"] = auth_header
        allow(JwtService).to receive(:decode).with(token).and_return({ "user_id" => 1 })
        allow(User).to receive(:find_by).with(id: 1).and_return(user)
      end

      it "allows the request through" do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it "sets current_user to the resolved user" do
        get :index
        expect(controller.current_user).to eq(user)
      end
    end

    context "with a valid JWT but no matching user" do
      before do
        request.headers["Authorization"] = auth_header
        allow(JwtService).to receive(:decode).with(token).and_return({ "user_id" => 999 })
        allow(User).to receive(:find_by).with(id: 999).and_return(nil)
      end

      it "returns 401 Unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it "renders the Unauthorized error message" do
        get :index
        expect(response.parsed_body["error"]).to eq("Unauthorized")
      end
    end

    context "with an invalid / expired JWT" do
      before do
        request.headers["Authorization"] = auth_header
        allow(JwtService).to receive(:decode).with(token).and_return(nil)
      end

      it "returns 401 Unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it "renders the Unauthorized error message" do
        get :index
        expect(response.parsed_body["error"]).to eq("Unauthorized")
      end
    end

    context "with no Authorization header" do
      before do
        allow(JwtService).to receive(:decode).with(nil).and_return(nil)
      end

      it "returns 401 Unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a malformed Authorization header (no Bearer prefix)" do
      before do
        request.headers["Authorization"] = token   # missing "Bearer "
        allow(JwtService).to receive(:decode).with(token).and_return(nil)
      end

      it "returns 401 Unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── extract_token_from_header ─────────────────────────────────────────────

  describe "#extract_token_from_header" do
    it "extracts the token from a well-formed Bearer header" do
      request.headers["Authorization"] = "Bearer my.jwt.token"
      expect(controller.send(:extract_token_from_header)).to eq("my.jwt.token")
    end

    it "returns nil when the Authorization header is absent" do
      expect(controller.send(:extract_token_from_header)).to be_nil
    end

    it "returns the last segment when the header has extra spaces" do
      request.headers["Authorization"] = "Bearer   extra.token"
      # split(" ").last strips the leading spaces and returns the last word
      expect(controller.send(:extract_token_from_header)).to eq("extra.token")
    end
  end

  # ─── Global error handlers ─────────────────────────────────────────────────

  describe "rescue_from handlers" do
    before do
      request.headers["Authorization"] = auth_header
      allow(JwtService).to receive(:decode).with(token).and_return({ "user_id" => 1 })
      allow(User).to receive(:find_by).with(id: 1).and_return(user)
    end

    context "ActiveRecord::RecordNotFound" do
      it "returns 404 Not Found" do
        get :trigger_not_found
        expect(response).to have_http_status(:not_found)
      end

      it "renders the exception message" do
        get :trigger_not_found
        expect(response.parsed_body["error"]).to include("Couldn't find Patient")
      end
    end

    context "ActiveRecord::RecordInvalid" do
      it "returns 422 Unprocessable Entity" do
        get :trigger_record_invalid
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "renders the validation error message" do
        get :trigger_record_invalid
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "ActionController::ParameterMissing" do
      it "returns 400 Bad Request" do
        get :trigger_parameter_missing
        expect(response).to have_http_status(:bad_request)
      end

      it "renders the missing parameter name in the error message" do
        get :trigger_parameter_missing
        expect(response.parsed_body["error"]).to include("email")
      end
    end

    context "Pundit::NotAuthorizedError" do
      it "returns 403 Forbidden" do
        get :trigger_not_authorized
        expect(response).to have_http_status(:forbidden)
      end

      it "renders the Forbidden error message" do
        get :trigger_not_authorized
        expect(response.parsed_body["error"]).to eq("Forbidden")
      end
    end
  end


  # ─── render_forbidden ──────────────────────────────────────────────────────
  # render_forbidden is not wired to any rescue_from handler — it must be
  # tested via a real dispatched request to avoid @_response being nil.

  describe "#render_forbidden" do
    before do
      request.headers["Authorization"] = auth_header
      allow(JwtService).to receive(:decode).with(token).and_return({ "user_id" => 1 })
      allow(User).to receive(:find_by).with(id: 1).and_return(user)
    end

    it "returns 403 Forbidden" do
      get :trigger_render_forbidden
      expect(response).to have_http_status(:forbidden)
    end

    it "renders the Forbidden error message" do
      get :trigger_render_forbidden
      expect(response.parsed_body["error"]).to eq("Forbidden")
    end
  end
end
