# frozen_string_literal: true

module FulfilApi
  class Relation
    # The {FulfilApi::Relation::Naming} extends the relation by
    #   adding methods to it that allow us to identify the type of resource that
    #   is being requested.
    module Naming
      extend ActiveSupport::Concern

      # Sets the name of the resource model to be queried.
      #
      # @todo In the future, derive the {#name} from the @resource_klass automatically.
      #
      # @param model_name [String] The name of the resource model in Fulfil.
      # @return [FulfilApi::Relation] A new {Relation} instance with the model name set.
      def set(model_name:)
        clone.tap do |relation|
          relation.model_name = model_name
        end
      end
    end
  end
end
