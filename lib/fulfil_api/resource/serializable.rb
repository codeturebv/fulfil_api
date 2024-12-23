# frozen_string_literal: true

module FulfilApi
  class Resource
    module Serializable
      extend ActiveSupport::Concern

      class_methods do
        # Turns a JSON string into a {FulfilApi::Resource}.
        #
        # @note it's required to include the name of the model as part of the JSON
        #   string too. Otherwise, you will encounter a naming error when attempting
        #   to turn the JSON into a {FulfilApi::Resource}
        #
        # @param json [String] The JSONified data
        # @param root_included [true, false] When using Rails, one can include
        # @return [FulfilApi::Resource]
        def from_json(json, root_included: false)
          attributes = JSON.parse(json)
          attributes = attributes.values.first if root_included

          new(attributes)
        end
      end

      # Overwrites the default {#as_json} method because {ActiveModel} will nest
      #   the attributes when the model is transformed to JSON.
      #
      # @param options [Hash, nil] An optional list of options
      # @return [Hash] A set of attributes available to be JSONified.
      def as_json(options = nil)
        # NOTE: We're including the model name by default. Otherwise, we can't use
        #   the {.from_json} method to parse it when reading from JSON.
        hash = to_h.merge("model_name" => @model_name)

        case options
        in { root: }
          { root => hash }
        else
          hash
        end
      end

      # Turns the {Resource} into a JSON object.
      #
      # @param options [Hash, nil] An optional list of options
      # @return [String] The JSONified resource data
      def to_json(options = nil)
        as_json(options).to_json
      end
    end
  end
end
