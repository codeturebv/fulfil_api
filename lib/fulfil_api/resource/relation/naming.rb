# frozen_string_literal: true

module FulfilApi
  class Resource
    class Relation
      # The {FulfilApi::Resource::Relation::Naming} extends the relation by
      #   adding methods to it that allow us to identify the type of resource that
      #   is being requested.
      module Naming
        extend ActiveSupport::Concern

        included do
          # Custom error class for missing model name. The model name is required to be
          #   able to build the API endpoint to perform the search/read HTTP request.
          class ModelNameMissing < Error; end # rubocop:disable Lint/ConstantDefinitionInBlock
        end

        # Sets the name of the resource model to be queried.
        #
        # @todo In the future, derive the {#name} from the @resource_klass automatically.
        #
        # @param model_name [String] The name of the resource model in Fulfil.
        # @return [FulfilApi::Resource::Relation] A new {Relation} instance with the model name set.
        def set(model_name:)
          clone.tap do |relation|
            relation.model_name = model_name
          end
        end
      end
    end
  end
end
