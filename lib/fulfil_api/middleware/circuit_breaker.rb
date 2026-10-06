# frozen_string_literal: true

module FulfilApi
  module Middleware
    # The {FulfilApi::Middleware::CircuitBreaker} runs every request through a
    #   [Faulty](https://github.com/ParentSquare/faulty) circuit, so a Fulfil instance
    #   that keeps failing is skipped for a while instead of tying up the threads of an
    #   application that talks to several of them.
    #
    # Each Fulfil instance gets its own circuit, shared by the {FulfilApi::Client} and
    #   the {FulfilApi::TplClient}. The thresholds and the storage come from the
    #   configured Faulty instance.
    #
    # It wraps the retries, so a request that failed after retrying counts as one
    #   failure. A response with a 4xx status code is an answer, and doesn't count.
    class CircuitBreaker < Faraday::Middleware
      # The errors that count as a failure of the Fulfil instance.
      FAILURES = [Faraday::ConnectionFailed, Faraday::ServerError, Faraday::TimeoutError].freeze

      # Faulty wraps the error of a failed request into one of its own. Raising the
      #   original error instead keeps the gem's errors the same with or without a
      #   circuit breaker. Only an open circuit, which has no original error, raises
      #   a {FulfilApi::CircuitOpen}.
      ERROR_MAPPER = lambda do |_error_name, cause, circuit|
        cause || FulfilApi::CircuitOpen.new("#{circuit.name} is open after repeated failures", details: {})
      end

      # @param env [Faraday::Env] The environment of the request.
      # @raise [FulfilApi::CircuitOpen] When the circuit of the Fulfil instance is open.
      # @return [Faraday::Response]
      def call(env)
        circuit_for(env).run { @app.call(env) }
      end

      private

      # @param env [Faraday::Env] The environment of the request.
      # @return [Faulty::Circuit]
      def circuit_for(env)
        options[:faulty].circuit("fulfil_api:#{env.url.host}", errors: FAILURES, error_mapper: ERROR_MAPPER)
      end
    end
  end
end
