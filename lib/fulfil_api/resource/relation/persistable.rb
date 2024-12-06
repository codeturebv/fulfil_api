# frozen_string_literal: true

module FulfilApi
  class Resource
    class Relation
      # The {FulfilApi::Resource::Relation::Loadable} extends the relation by
      #   adding methods to create a resource
      module Persistable
        # Creates a new resource on the model name.
        #
        # @params attributes [Hash, Array] Attributes to create an object with or a list of attributes.
        # @return [FulfilApi::Resource, Array, false] The created resource or a list of created resources.
        #
        # @example Creating a resource
        #   FulfilApi::Resource.set(model_name: "sale.sale").create({ reference: "MK123" })
        def create(*attributes)
          create!(attributes)
        rescue FulfilApi::Error, ModelNameMissing
          false
        end

        # Creates a new resource on the model name, raising an error if the create fails.
        #
        # @params attributes [Array, Hash] Attributes to create an object with or a list of attributes.
        # @return [FulfilApi::Resource, Array] The created resource or a list of created resources.
        # @raise [FulfilApi::Error] If the create fails.
        #
        # @example Creating a resource
        #   FulfilApi::Resource.set(model_name: "sale.sale").create!({ reference: "MK123" })
        def create!(*attributes)
          raise ModelNameMissing, "The model name is missing. Use #set to define it." if model_name.nil?

          response = FulfilApi.client.post("/model/#{model_name}", body: attributes.flatten)
          return response.first if response.one?

          response
        end
      end
    end
  end
end
