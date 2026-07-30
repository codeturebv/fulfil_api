# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Error} is the base class for all FulfilApi errors, also used
  #   for generic or unexpected errors.
  class Error < StandardError
    UNAUTHORIZED_STATUS = 401

    attr_reader :details

    # Builds the error that fits the response Fulfil sent back, so a caller can
    #   tell rejected credentials apart from everything else that can go wrong.
    #
    # @param message [String] The displayable error message for the receiver.
    # @param details [Hash] Any additional details exposed by the issuer of the exception.
    # @return [FulfilApi::Error]
    def self.from_response(message, details:)
      error_class = details[:response_status] == UNAUTHORIZED_STATUS ? UnauthorizedError : Error
      error_class.new(message, details: details)
    end

    # @param message [String] The displayable error message for the receiver.
    # @param details [Hash] Any additional details exposed by the issuer of the exception.
    def initialize(message, details: nil)
      @details = details
      super(message)
    end

    # @return [String]
    def message
      body_message = parsed_body_message
      return "[#{self.class.name}] #{body_message}" if body_message

      "[#{self.class.name}] #{super}"
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
