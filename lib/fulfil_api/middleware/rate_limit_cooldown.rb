# frozen_string_literal: true

module FulfilApi
  module Middleware
    # The {FulfilApi::Middleware::RateLimitCooldown} keeps every thread and process of an
    #   application from calling a Fulfil instance that just rate limited one of them.
    #
    # Fulfil doesn't publish its rate limits, and they differ per merchant, so instead of
    #   counting requests against a guessed limit, the cooldown reacts to Fulfil itself:
    #   the first 429 starts a cooldown for that Fulfil instance in a shared store, and
    #   until it has passed, requests are refused locally with the same 429 instead of
    #   being sent. The refusal carries a `retry-after` header with the seconds left, so
    #   the retries of {FulfilApi::Relation::Batchable#in_batches} (and any retry an
    #   application has for {FulfilApi::HttpError::TooManyRequests}) wait just long enough.
    #
    # The cooldown lasts as long as Fulfil's `Retry-After` header asks, or {DEFAULT_WAIT}
    #   seconds when it doesn't say, and never longer than {MAX_WAIT}. The store is any
    #   `ActiveSupport::Cache::Store`; use one every process shares (e.g. Redis) for the
    #   cooldown to reach all of them.
    class RateLimitCooldown < Faraday::Middleware
      # The cooldown in seconds when Fulfil's 429 doesn't come with a `Retry-After` header.
      DEFAULT_WAIT = 2

      # The longest cooldown in seconds, also when Fulfil asks for longer.
      MAX_WAIT = 30

      # @param env [Faraday::Env] The environment of the request.
      # @raise [Faraday::TooManyRequestsError] While the Fulfil instance is cooling down.
      # @return [Faraday::Response]
      def call(env)
        refuse!(env) if cooling_down?(env)

        @app.call(env)
      rescue Faraday::TooManyRequestsError => e
        start_cooldown(env, e) unless refused?(e)
        raise
      end

      private

      # @param env [Faraday::Env]
      # @return [String] The key of the cooldown of the Fulfil instance in the store.
      def cache_key(env)
        "fulfil_api:rate_limit_cooldown:#{env.url.host}"
      end

      # @param env [Faraday::Env]
      # @return [Boolean]
      def cooling_down?(env)
        remaining_wait(env).positive?
      end

      # @param env [Faraday::Env]
      # @return [Float] The seconds left in the cooldown of the Fulfil instance.
      def remaining_wait(env)
        cooldown_until = store.read(cache_key(env)).to_f
        [cooldown_until - Time.now.to_f, 0].max
      end

      # @param env [Faraday::Env]
      # @raise [Faraday::TooManyRequestsError]
      def refuse!(env)
        response = {
          status: 429,
          headers: { "retry-after" => remaining_wait(env).ceil.to_s, "x-fulfil-api-cooldown" => "true" },
          body: { "error" => "#{env.url.host} rate limited an earlier request, waiting for its cooldown" }
        }

        raise Faraday::TooManyRequestsError.new("the rate limit cooldown of #{env.url.host} is active", response)
      end

      # @param error [Faraday::TooManyRequestsError]
      # @return [Boolean] Whether the error is a refusal of this middleware.
      def refused?(error)
        error.response_headers.to_h.key?("x-fulfil-api-cooldown")
      end

      # Starts (or extends, never shortens) the cooldown of the Fulfil instance.
      #
      # @param env [Faraday::Env]
      # @param error [Faraday::TooManyRequestsError] The 429 of Fulfil.
      # @return [void]
      def start_cooldown(env, error)
        wait = [requested_wait(error) || DEFAULT_WAIT, MAX_WAIT].min
        cooldown_until = Time.now.to_f + wait
        return if store.read(cache_key(env)).to_f >= cooldown_until

        store.write(cache_key(env), cooldown_until, expires_in: wait.ceil)
      end

      # @param error [Faraday::TooManyRequestsError]
      # @return [Integer, nil] The seconds Fulfil asked to wait, when it said so.
      def requested_wait(error)
        value = error.response_headers.to_h.find { |name, _| name.to_s.casecmp?("retry-after") }&.last
        return if value.blank?

        value.to_s.match?(/\A\d+\z/) ? value.to_i : [(Time.httpdate(value.to_s) - Time.now).ceil, 0].max
      rescue ArgumentError
        nil
      end

      # @return [ActiveSupport::Cache::Store]
      def store
        options[:store]
      end
    end
  end
end
