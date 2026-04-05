# spec/middleware/rate_limiter_spec.rb
RSpec.describe Middleware::RateLimiter do
  # ── Helpers ────────────────────────────────────────────────────────────────
  let(:inner_app) do
    ->(env) { [ 200, { "Content-Type" => "application/json" }, [ "OK" ] ] }
  end

  let(:redis)      { instance_double(Redis) }
  let(:middleware) { described_class.new(inner_app) }

  before do
    allow(Redis).to receive(:new).and_return(redis)
    # Middleware short-circuits in test env — force non-test for all examples
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
  end

  # Build a minimal Rack env for a given path and optional Authorization header
  def make_env(path: "/api/v1/patients", ip: "1.2.3.4", token: nil)
    env = Rack::MockRequest.env_for("http://example.com#{path}", "REMOTE_ADDR" => ip)
    env["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    env
  end

  # ─── LIMITS constant ───────────────────────────────────────────────────────

  describe "LIMITS" do
    it "defines a strict limit for the auth endpoint" do
      expect(described_class::LIMITS["/api/v1/auth"]).to eq(requests: 5, window: 60)
    end

    it "defines a default limit for all other endpoints" do
      expect(described_class::LIMITS["default"]).to eq(requests: 100, window: 60)
    end

    it "is frozen" do
      expect(described_class::LIMITS).to be_frozen
    end
  end

  # ─── Rails.env.test? short-circuit ────────────────────────────────────────

  describe "test environment bypass" do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
    end

    it "skips rate limiting entirely and passes the request through" do
      allow(redis).to receive(:get)   # must be stubbed for have_received to work
      env = make_env
      status, _, _ = described_class.new(inner_app).call(env)
      expect(status).to eq(200)
      expect(redis).not_to have_received(:get)
    end
  end

  # ─── #call – under the limit ───────────────────────────────────────────────

  describe "#call — request allowed" do
    let(:key) { "rate_limit:ip:1.2.3.4:/api/v1/patients" }

    before do
      allow(redis).to receive(:get).with(key).and_return("10")   # well under 100
      allow(redis).to receive(:multi).and_yield(redis)
      allow(redis).to receive(:incr)
      allow(redis).to receive(:expire)
    end

    it "returns the inner app's status" do
      status, _, _ = middleware.call(make_env)
      expect(status).to eq(200)
    end

    it "sets X-RateLimit-Limit header" do
      _, headers, _ = middleware.call(make_env)
      expect(headers["X-RateLimit-Limit"]).to eq("100")
    end

    it "sets X-RateLimit-Remaining header correctly" do
      _, headers, _ = middleware.call(make_env)
      # 100 max - 10 current - 1 = 89
      expect(headers["X-RateLimit-Remaining"]).to eq("89")
    end

    it "sets X-RateLimit-Window header" do
      _, headers, _ = middleware.call(make_env)
      expect(headers["X-RateLimit-Window"]).to eq("60s")
    end

    it "increments the Redis counter" do
      middleware.call(make_env)
      expect(redis).to have_received(:incr).with(key)
    end

    it "does not set expiry when count is not zero (key already has TTL)" do
      middleware.call(make_env)
      expect(redis).not_to have_received(:expire)
    end

    context "when this is the very first request (count == 0)" do
      before { allow(redis).to receive(:get).with(key).and_return("0") }

      it "sets the expiry on the key" do
        middleware.call(make_env)
        expect(redis).to have_received(:expire).with(key, 60)
      end

      it "sets X-RateLimit-Remaining to max - 1" do
        _, headers, _ = middleware.call(make_env)
        expect(headers["X-RateLimit-Remaining"]).to eq("99")
      end
    end
  end

  # ─── #call – auth endpoint uses tighter limit ─────────────────────────────

  describe "#call — /api/v1/auth endpoint limits" do
    let(:key) { "rate_limit:ip:1.2.3.4:/api/v1/auth" }

    before do
      allow(redis).to receive(:get).with(key).and_return("3")   # under the 5-req limit
      allow(redis).to receive(:multi).and_yield(redis)
      allow(redis).to receive(:incr)
      allow(redis).to receive(:expire)
    end

    it "applies the 5 requests/min limit" do
      _, headers, _ = middleware.call(make_env(path: "/api/v1/auth"))
      expect(headers["X-RateLimit-Limit"]).to eq("5")
    end

    it "calculates remaining correctly against the tighter limit" do
      _, headers, _ = middleware.call(make_env(path: "/api/v1/auth"))
      # 5 - 3 - 1 = 1
      expect(headers["X-RateLimit-Remaining"]).to eq("1")
    end
  end

  # ─── #call – rate limit exceeded ──────────────────────────────────────────

  describe "#call — rate limit exceeded" do
    let(:key) { "rate_limit:ip:1.2.3.4:/api/v1/patients" }

    before do
      allow(redis).to receive(:get).with(key).and_return("100")  # == max_requests
    end

    it "returns HTTP 429" do
      status, _, _ = middleware.call(make_env)
      expect(status).to eq(429)
    end

    it "does not call the inner app" do
      calls = 0
      app   = ->(env) { calls += 1; [ 200, {}, [ "OK" ] ] }
      described_class.new(app).call(make_env)
      expect(calls).to eq(0)
    end

    it "sets Content-Type to application/json" do
      _, headers, _ = middleware.call(make_env)
      expect(headers["Content-Type"]).to eq("application/json")
    end

    it "sets X-RateLimit-Remaining to 0" do
      _, headers, _ = middleware.call(make_env)
      expect(headers["X-RateLimit-Remaining"]).to eq("0")
    end

    it "sets X-RateLimit-Limit to the max" do
      _, headers, _ = middleware.call(make_env)
      expect(headers["X-RateLimit-Limit"]).to eq("100")
    end

    it "sets Retry-After to the window" do
      _, headers, _ = middleware.call(make_env)
      expect(headers["Retry-After"]).to eq("60")
    end

    it "renders the Too Many Requests error body" do
      _, _, body = middleware.call(make_env)
      parsed = JSON.parse(body.first)
      expect(parsed["error"]).to eq("Too Many Requests")
      expect(parsed["message"]).to include("100")
      expect(parsed["message"]).to include("60s")
    end

    it "does not increment the Redis counter when limit is hit" do
      allow(redis).to receive(:multi)  # must be stubbed for have_received to work
      middleware.call(make_env)
      expect(redis).not_to have_received(:multi)
    end
  end

  # ─── #build_identifier ─────────────────────────────────────────────────────

  describe "#build_identifier (via key used in Redis calls)" do
    context "when a valid JWT is present" do
      let(:token)   { "valid.jwt.token" }
      let(:decoded) { { "user_id" => 42 } }
      let(:key)     { "rate_limit:user:42:/api/v1/patients" }

      before do
        allow(JwtService).to receive(:decode).with(token).and_return(decoded)
        allow(redis).to receive(:get).with(key).and_return("0")
        allow(redis).to receive(:multi).and_yield(redis)
        allow(redis).to receive(:incr)
        allow(redis).to receive(:expire)
      end

      it "identifies the request by user_id" do
        middleware.call(make_env(token: token))
        expect(redis).to have_received(:get).with(key)
      end
    end

    context "when no JWT is present" do
      let(:key) { "rate_limit:ip:1.2.3.4:/api/v1/patients" }

      before do
        allow(redis).to receive(:get).with(key).and_return("0")
        allow(redis).to receive(:multi).and_yield(redis)
        allow(redis).to receive(:incr)
        allow(redis).to receive(:expire)
      end

      it "falls back to the IP address" do
        middleware.call(make_env)
        expect(redis).to have_received(:get).with(key)
      end
    end

    context "when a JWT is present but invalid (decode returns nil)" do
      let(:token) { "bad.token" }
      let(:key)   { "rate_limit:ip:1.2.3.4:/api/v1/patients" }

      before do
        allow(JwtService).to receive(:decode).with(token).and_return(nil)
        allow(redis).to receive(:get).with(key).and_return("0")
        allow(redis).to receive(:multi).and_yield(redis)
        allow(redis).to receive(:incr)
        allow(redis).to receive(:expire)
      end

      it "falls back to the IP address" do
        middleware.call(make_env(token: token))
        expect(redis).to have_received(:get).with(key)
      end
    end
  end

  # ─── Redis failure – fail open ─────────────────────────────────────────────

  describe "#call — Redis::BaseError fail-open" do
    before do
      allow(redis).to receive(:get).and_raise(Redis::BaseError, "connection refused")
      allow(Rails.logger).to receive(:error)
    end

    it "passes the request through to the inner app" do
      status, _, _ = middleware.call(make_env)
      expect(status).to eq(200)
    end

    it "logs the Redis error" do
      middleware.call(make_env)
      expect(Rails.logger).to have_received(:error)
        .with(a_string_including("RateLimiter Redis error"))
    end

    it "does not raise an exception to the caller" do
      expect { middleware.call(make_env) }.not_to raise_error
    end
  end

  # ─── X-RateLimit-Remaining floor ──────────────────────────────────────────

  describe "X-RateLimit-Remaining floor" do
    # If somehow current_count > max (e.g. race condition before limit check),
    # remaining must never go negative.
    let(:key) { "rate_limit:ip:1.2.3.4:/api/v1/patients" }

    before do
      allow(redis).to receive(:get).with(key).and_return("99")   # == max - 1, passes check
      allow(redis).to receive(:multi).and_yield(redis)
      allow(redis).to receive(:incr)
      allow(redis).to receive(:expire)
    end

    it "clamps X-RateLimit-Remaining to 0 when consumed" do
      _, headers, _ = middleware.call(make_env)
      # 100 - 99 - 1 = 0
      expect(headers["X-RateLimit-Remaining"].to_i).to be >= 0
    end
  end
end
