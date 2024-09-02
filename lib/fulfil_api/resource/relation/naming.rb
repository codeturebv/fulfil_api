# frozen_string_literal: true

module FulfilApi
  class Resource
    class Relation
      module Naming
        # Custom error class for missing model name. The model name is required to be
        #   able to build the API endpoint to perform the search/read HTTP request.
        class ModelNameMissing < Error; end

        # Sets the name of the resource model to be queried.
        #
        # @todo In the future, derive the {#name} from the @resource_klass automatically.
        #
        # @param name [String] The name of the resource model in Fulfil.
        # @return [FulfilApi::Resource::Relation] A new {Relation} instance with the model name set.
        def set(name:)
          clone.tap do |relation|
            relation.name = name
          end
        end
      end
    end
  end
end
