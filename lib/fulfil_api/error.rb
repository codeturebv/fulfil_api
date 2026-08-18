# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Error} is the base class for all FulfilApi errors, also used
  #   for generic or unexpected errors.
  #
  # Raising any of them publishes an {ActiveSupport::Notifications} event, so an
  #   application can report the failure to its APM without rescuing every call into
  #   the gem. See {FulfilApi::Error::Notifiable} and {FulfilApi.on_error}.
  class Error < StandardError
    include Notifiable

    attr_reader :details

    # @param message [String] The displayable error message for the receiver.
    # @param details [Hash] Any additional details exposed by the issuer of the exception.
    def initialize(message, details: nil)
      @details = details
      super(message)
    end

    # @return [String]
    def message
      body_message = parsed_body_message
      return "[FulfilApi::Error] #{body_message}" if body_message

      "[FulfilApi::Error] #{super}"
    end

    private

    def parsed_body_message
      body = details&.dig(:response_body)
      return unless body

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end
  end

  # Subscribes to every {FulfilApi::Error} raised by the gem.
  #
  # This is the shorthand for the common case: reporting the failure somewhere. To
  #   reach the HTTP status code, response body and response headers of a
  #   {FulfilApi::HttpError} as well, subscribe to {FulfilApi::Error::EVENT_NAME}
  #   through {ActiveSupport::Notifications} directly.
  #
  # @example incrementing a counter of an APM
  #   # config/initializers/fulfil_api.rb
  #   FulfilApi.on_error do |error|
  #     Appsignal.increment_counter("fulfil_api_errors", 1, error: error.class.name)
  #   end
  #
  # @example reporting only the rate limit hits
  #   FulfilApi.on_error do |error|
  #     next unless error.is_a?(FulfilApi::HttpError::TooManyRequests)
  #
  #     Appsignal.increment_counter("fulfil_api_rate_limit_exceeded")
  #   end
  #
  # @note The block runs while the error travels up the stack, on the thread that
  #   raised it. Keep it cheap, and hand anything slow to a background job.
  #
  # @yieldparam error [FulfilApi::Error] The error being raised.
  # @return [Object] The subscriber, to hand back to
  #   `ActiveSupport::Notifications.unsubscribe` to stop listening.
  def self.on_error
    ActiveSupport::Notifications.subscribe(Error::EVENT_NAME) do |event|
      yield(event.payload[:exception_object])
    end
  end
end
