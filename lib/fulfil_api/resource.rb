# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Resource} represents a single resource returned by the API
  #   endpoints of Fulfil.
  class Resource
    include AttributeAssignable
    include Persistable

    # The model name is required to be able to build the API endpoint to
    #   perform the search/read/count HTTP requests.
    class ModelNameMissing < Error
      def initialize
        super("The model name is missing. Use #set to define it.")
      end
    end

    class NotFound < Error; end

    def initialize(attributes = {})
      attributes.deep_stringify_keys!

      @attributes = {}.with_indifferent_access
      @model_name = attributes.delete("model_name").presence || raise(ModelNameMissing)

      assign_attributes(attributes)
    end

    class << self
      delegate_missing_to :relation

      # Builds a new {Fulfil::Resource::Relation} based on the current class to
      #   enable us to chain requests to Fulfil without querying their API endpoints
      #   multiple times in a row.
      #
      # @note it makes use of the {.delegate_missing_to} method from {ActiveSupport}
      #   to ensure that all unknown class methods for the {FulfilApi::Resource} are
      #   forwarded to the {FulfilApi::Resource.relation}.
      #
      # @example forwarding of the .where class method
      #   FulfilApi::Resource.set(model_name: "sale.sale").find_by(["id", "=", 100])
      #
      # @return [FulfilApi::Resource::Relation]
      def relation
        Relation.new(self)
      end
    end

    # Looks up the value for the given attribute name.
    #
    # @param attribute_name [String, Symbol] The name of the attribute
    # @return [Any, nil]
    def [](attribute_name)
      @attributes[attribute_name]
    end

    # Builds a structure for keeping track of any errors when trying to use the
    #   persistance methods for the API resource.
    #
    # @return [FulfilApi::Resource::Errors]
    def errors
      @errors ||= Errors.new(self)
    end

    # The {#id} is a shorthand to easily grab the ID of an API resource.
    #
    # @return [Integer, nil]
    def id
      @attributes["id"]
    end

    # Returns all currently assigned attributes for a {FulfilApi::Resource}.
    #
    # @return [Hash]
    def to_h
      @attributes
    end

    private

    attr_reader :model_name

    def handle_exception(exception) # rubocop:disable Metrics/AbcSize
      case (error = JSON.parse(exception.details[:response_body]).deep_symbolize_keys!)
      in { type: "UserError" }
        errors.add(code: error[:code], type: :user, message: error[:message])
      in { code: Integer, name: String, description: String }
        errors.add(code: error[:code], type: :authorization, message: error[:description])
      else
        errors.add(code: exception.details[:response_status], type: :system, message: exception.details[:response_body])
      end

      self
    end
  end
end
