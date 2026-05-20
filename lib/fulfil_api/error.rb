# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Error} is the base class for all FulfilApi errors, also used
  #   for generic or unexpected errors.
  class Error < StandardError
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
end
