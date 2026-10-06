# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Middleware} sets up the Faraday middleware that both the
  #   {FulfilApi::Client} and the {FulfilApi::TplClient} run their requests through.
  module Middleware
    # The errors raised when a request never got an answer from Fulfil. An HTTP
    #   error response is an answer, and is never retried.
    RETRYABLE_ERRORS = [Faraday::ConnectionFailed, Faraday::TimeoutError].freeze

    class << self
      # Adds the gem's middleware to a Faraday connection. Middleware runs in the
      #   order it's added, so the first one wraps everything after it.
      #
      # @param connection [Faraday::Connection] The connection being built.
      # @param configuration [FulfilApi::Configuration] The configuration of the client.
      # @return [void]
      def apply(connection, configuration)
        connection.use CircuitBreaker, faulty: configuration.circuit_breaker if configuration.circuit_breaker
        connection.request :retry, retry_middleware_options(configuration.retry_options)
      end

      private

      # Translates the {FulfilApi::Configuration#retry_options} into the options of
      #   the `faraday-retry` middleware.
      #
      # Ruby's built-in retry, and `faraday-retry` by default, treat every PUT as
      #   idempotent, while Fulfil uses PUT both to read (`search_read`,
      #   `search_count`) and to write (updating a record, holding a shipment).
      #   Retrying a write that timed out could apply it twice, so no HTTP verb is
      #   retried wholesale and every request is matched against the configured
      #   endpoints instead.
      #
      # @param options [Hash] The retry options of the configuration.
      # @return [Hash]
      def retry_middleware_options(options)
        requests = options.fetch(:requests, {})

        {
          max: options.fetch(:max_retries, 0),
          methods: [],
          exceptions: RETRYABLE_ERRORS,
          retry_if: ->(env, _exception) { retryable_request?(env, requests) }
        }
      end

      # @param env [Faraday::Env] The environment of the request.
      # @param requests [Hash] The HTTP verbs mapped onto their retryable endpoints.
      # @return [true, false] Whether the endpoint of the request is safe to retry.
      def retryable_request?(env, requests)
        patterns = requests[env.method]
        return true if patterns == true

        Array(patterns).any? { |pattern| pattern.match?(env.url.path) }
      end
    end
  end
end
