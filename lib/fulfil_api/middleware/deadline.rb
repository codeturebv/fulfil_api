# frozen_string_literal: true

module FulfilApi
  module Middleware
    # The {FulfilApi::Middleware::Deadline} stops a request from being sent once the
    #   deadline of the current thread has run out.
    #
    # @see FulfilApi.with_deadline
    class Deadline < Faraday::Middleware
      # @param env [Faraday::Env] The environment of the request.
      # @raise [FulfilApi::Deadline::Exceeded] When the deadline has run out.
      # @return [Faraday::Response]
      def call(env)
        if FulfilApi::Deadline.current&.expired?
          raise FulfilApi::Deadline::Exceeded.new(
            "The deadline ran out before #{env.method.upcase} #{env.url.path} could be sent", details: {}
          )
        end

        @app.call(env)
      end
    end
  end
end
