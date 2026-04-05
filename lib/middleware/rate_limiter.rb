# app/middleware/rate_limiter.rb
module Middleware
  class RateLimiter
    # ── Configuration ────────────────────────────────────────────────────────
    LIMITS = {
      "/api/v1/auth"  => { requests: 5,   window: 60  },  # 5 req/min  (login brute force)
      "default"       => { requests: 100, window: 60  }   # 100 req/min (all other endpoints)
    }.freeze

    def initialize(app)
      @app   = app
      @redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end

    def call(env)
      return @app.call(env) if Rails.env.test?
      request = Rack::Request.new(env)

      limit_config = LIMITS[request.path] || LIMITS["default"]
      max_requests = limit_config[:requests]
      window       = limit_config[:window]

      identifier = build_identifier(request)
      key        = "rate_limit:#{identifier}:#{request.path}"

      current_count = @redis.get(key).to_i

      if current_count >= max_requests
        return rate_limit_response(max_requests, window)
      end

      # Increment and set expiry atomically
      @redis.multi do |r|
        r.incr(key)
        r.expire(key, window) if current_count.zero?
      end

      # Pass remaining info in response headers
      status, headers, body = @app.call(env)

      headers["X-RateLimit-Limit"]     = max_requests.to_s
      headers["X-RateLimit-Remaining"] = [ max_requests - current_count - 1, 0 ].max.to_s
      headers["X-RateLimit-Window"]    = "#{window}s"

      [ status, headers, body ]
    rescue Redis::BaseError => e
      # ── If Redis is down, fail open (don't block requests) ─────────────────
      Rails.logger.error("RateLimiter Redis error: #{e.message}")
      @app.call(env)
    end

    private

    def build_identifier(request)
      # Use JWT user_id if available, fall back to IP
      token = request.env["HTTP_AUTHORIZATION"]&.split(" ")&.last

      if token
        decoded = JwtService.decode(token)
        return "user:#{decoded['user_id']}" if decoded
      end

      "ip:#{request.ip}"
    end

    def rate_limit_response(max_requests, window)
      body = JSON.generate({
        error:   "Too Many Requests",
        message: "Rate limit of #{max_requests} requests per #{window}s exceeded"
      })

      [
        429,
        {
          "Content-Type"    => "application/json",
          "X-RateLimit-Limit" => max_requests.to_s,
          "X-RateLimit-Remaining" => "0",
          "Retry-After"     => window.to_s
        },
        [ body ]
      ]
    end
  end
end
