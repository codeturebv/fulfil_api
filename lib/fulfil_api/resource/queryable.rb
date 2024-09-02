# frozen_string_literal: true

module FulfilApi
  class Resource
    # The {FulfilApi::Resource::Queryable} module adds query-related methods to the {Resource} class.
    #
    # It provides a set of class-level methods similar to ActiveRecord, enabling more convenient
    #   and readable querying of API resources.
    module Queryable
      extend ActiveSupport::Concern

      class_methods do
        # Finds the first resource that matches the given conditions.
        #
        # @param conditions [Array<String, String, String>] The filter conditions as required by Fulfil.
        # @return [FulfilApi::Resource, nil] The first resource that matches the conditions, or nil if no match is found.
        def find_by(conditions)
          Relation.new(self).find_by(conditions)
        end

        # Selects specific fields to be included in the response from Fulfil's API.
        #
        # Returns a new {Relation} instance initialized with the current class and the specified fields.
        #
        # @param fields [Array<Symbol, String>] The fields to include in the response.
        # @return [FulfilApi::Resource::Relation] A new {Relation} instance with the selected fields.
        def select(*fields)
          Relation.new(self).select(*fields)
        end

        # Sets the name of the resource model to be queried.
        #
        # Returns a new {Relation} instance initialized with the current class and the specified model name.
        #
        # @param name [String] The name of the resource model in Fulfil.
        # @return [FulfilApi::Resource::Relation] A new {Relation} instance with the model name set.
        def set(name:)
          Relation.new(self).set(name: name)
        end

        # Adds filter conditions for querying Fulfil's API.
        #
        # Returns a new {Relation} instance initialized with the current class and the specified conditions.
        #
        # @param conditions [Array<String, String, String>] The filter conditions as required by Fulfil.
        # @return [FulfilApi::Resource::Relation] A new {Relation} instance with the conditions applied.
        def where(conditions)
          Relation.new(self).where(conditions)
        end
      end
    end
  end
end
