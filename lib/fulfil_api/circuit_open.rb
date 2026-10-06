# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::CircuitOpen} is raised instead of sending a request while the
  #   circuit breaker has the Fulfil instance marked as failing.
  #
  # @see FulfilApi::Middleware::CircuitBreaker
  class CircuitOpen < Error; end
end
