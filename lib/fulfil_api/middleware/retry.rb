# frozen_string_literal: true

module FulfilApi
  module Middleware
    # The {FulfilApi::Middleware::Retry} retries a request that failed before Fulfil
    #   could answer it, but only for the endpoints configured as safe to retry.
    #
    # Ruby's built-in retry treats every PUT as idempotent, while Fulfil uses PUT both
    #   to read (`search_read`, `search_count`) and to write (updating a record,
    #   holding a shipment). Retrying a write that timed out could apply it twice, so
    #   the endpoints are matched explicitly instead.
    #
    # A request is not retried once the deadline of {FulfilApi.with_deadline} has run
    #   out; the original error is raised instead.
    #
    # @see FulfilApi::Configuration::DEFAULT_RETRY_OPTIONS
    class Retry < Faraday::Middleware
      # The errors raised when a request never got an answer from Fulfil. An HTTP
      #   error response is an answer, and is never retried.
      RETRYABLE_ERRORS = [Faraday::ConnectionFailed, Faraday::TimeoutError].freeze

      # @param app [#call] The next middleware in the stack.
      # @param options [Hash] The retry options, see {FulfilApi::Configuration#retry_options}.
      def initialize(app, options = {})
        super
        @max_retries = options.fetch(:max_retries, 0)
        @requests = options.fetch(:requests, {})
      end

      # @param env [Faraday::Env] The environment of the request.
      # @return [Faraday::Response]
      def call(env)
        request_body = env.body
        retries = 0

        begin
          @app.call(env)
        rescue *RETRYABLE_ERRORS
          raise unless retries < max_retries && retryable?(env) && !deadline_expired?

          retries += 1
          env.body = request_body
          retry
        end
      end

      private

      attr_reader :max_retries, :requests

      # @return [true, false]
      def deadline_expired?
        FulfilApi::Deadline.current&.expired? || false
      end

      # @param env [Faraday::Env] The environment of the request.
      # @return [true, false] Whether the endpoint of the request is safe to retry.
      def retryable?(env)
        patterns = requests[env.method]
        return true if patterns == true

        Array(patterns).any? { |pattern| pattern.match?(env.url.path) }
      end
    end
  end
end
