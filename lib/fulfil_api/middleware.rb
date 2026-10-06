# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Middleware} holds the Faraday middleware that both the
  #   {FulfilApi::Client} and the {FulfilApi::TplClient} run their requests through.
  module Middleware
    # Adds the gem's middleware to a Faraday connection. Middleware runs in the
    #   order it's added, so the first one wraps everything after it.
    #
    # @param connection [Faraday::Connection] The connection being built.
    # @param configuration [FulfilApi::Configuration] The configuration of the client.
    # @return [void]
    def self.apply(connection, configuration)
      connection.use CircuitBreaker, configuration.circuit_breaker if configuration.circuit_breaker
      connection.use Retry, configuration.retry_options
      connection.use Deadline
    end
  end
end
