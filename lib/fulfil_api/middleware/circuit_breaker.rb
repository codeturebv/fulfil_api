# frozen_string_literal: true

module FulfilApi
  module Middleware
    # The {FulfilApi::Middleware::CircuitBreaker} stops sending requests to a Fulfil
    #   instance that keeps failing, so a struggling instance can't tie up the threads
    #   of an application that talks to several of them.
    #
    # It wraps the retries, so a request that failed after retrying counts as one
    #   failure. A response with a 4xx status code is an answer, and doesn't count.
    #
    # @see FulfilApi::Circuit
    class CircuitBreaker < Faraday::Middleware
      # The errors that count as a failure of the Fulfil instance.
      FAILURES = [Faraday::ConnectionFailed, Faraday::ServerError, Faraday::TimeoutError].freeze

      # @param env [Faraday::Env] The environment of the request.
      # @raise [FulfilApi::Circuit::Open] When the circuit of the Fulfil instance is open.
      # @return [Faraday::Response]
      def call(env)
        circuit = FulfilApi::Circuit.new(env.url.host, **options)
        raise open_circuit_error(env) if circuit.open?

        begin
          @app.call(env)
        rescue *FAILURES
          circuit.record_failure
          raise
        end
      end

      private

      # @param env [Faraday::Env] The environment of the request.
      # @return [FulfilApi::Circuit::Open]
      def open_circuit_error(env)
        FulfilApi::Circuit::Open.new(
          "#{env.url.host} failed repeatedly, so #{env.method.upcase} #{env.url.path} wasn't sent", details: {}
        )
      end
    end
  end
end
