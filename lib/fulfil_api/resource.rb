# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Resource} represents a single resource returned by the API
  #   endpoints of Fulfil.
  class Resource
    include AttributeAssignable

    def initialize(attributes = {})
      @attributes = {}.with_indifferent_access
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
      #   FulfilApi::Resource.set(name: "sale.sale").find_by(["id", "=", 100])
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

    # Returns all currently assigned attributes for a {FulfilApi::Resource}.
    #
    # @return [Hash]
    def to_h
      @attributes
    end
  end
end
