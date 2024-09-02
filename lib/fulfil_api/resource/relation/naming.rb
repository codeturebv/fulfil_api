# frozen_string_literal: true

module FulfilApi
  class Resource
    class Relation
      # The {FulfilApi::Resource::Relation::Naming} extends the relation by
      #   adding methods to it that allow us to identify the type of resource that
      #   is being requested.
      module Naming
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
