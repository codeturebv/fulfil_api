# frozen_string_literal: true

module FulfilApi
  class Resource
    include AttributeAssignable

    def initialize(attributes = {})
      @attributes = {}.with_indifferent_access
      assign_attributes(attributes)
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
