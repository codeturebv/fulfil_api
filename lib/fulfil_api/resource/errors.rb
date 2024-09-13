# frozen_string_literal: true

module FulfilApi
  class Resource
    # The Errors class provides a structure to track and manage errors related to a API resource.
    class Errors
      include Enumerable

      delegate :each, :empty?, to: :@errors

      # @param resource_klass [FulfilApi::Resource] The resource class that this Errors instance is associated with.
      def initialize(resource_klass)
        @errors = []
        @resource_klass = resource_klass
      end

      # Adds a new error to the collection, unless the same error already exists.
      #
      # @param code [String, Symbol] The error code.
      # @param message [String] A description of the error.
      # @param type [String, Symbol] The type of the error (e.g., user, authorization).
      # @return [Array<Hash>] The updated list of errors.
      #
      # @example Adding an error
      #   errors.add(code: "invalid_field", message: "Field is required", type: "validation")
      def add(code:, message:, type:)
        @errors << { code: code.to_s, type: type.to_sym, message: message } unless added?(code: code, type: type)
        @errors
      end

      # Checks if an error with the specified code and type has already been added.
      #
      # @param code [String, Symbol] The error code to check.
      # @param type [String, Symbol] The error type to check.
      # @return [Boolean] True if the error has already been added, false otherwise.
      #
      # @example Checking if an error exists
      #   errors.added?(code: "invalid_field", type: "validation")
      def added?(code:, type:)
        @errors.any? do |error|
          error[:code] == code.to_s && error[:type] == type.to_sym
        end
      end

      # Clears all errors from the collection.
      #
      # @return [Array] The cleared list of errors
      #
      # @example Clearing all errors
      #   errors.clear
      def clear
        @errors = []
        @errors
      end

      # Returns an array of the full error messages (just the message field).
      #
      # @return [Array<String>] The list of error messages.
      #
      # @example Retrieving full error messages
      #   errors.full_messages
      def full_messages
        @errors.pluck(:message)
      end

      # Returns the collection of error messages as an array of hashes.
      #
      # @return [Array<Hash>] The array of error hashes.
      #
      # @example Retrieving all error messages
      #   errors.messages
      def messages
        @errors
      end
    end
  end
end
