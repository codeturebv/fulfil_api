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
      "[FulfilApi::Error] #{super}"
    end
  end
end
