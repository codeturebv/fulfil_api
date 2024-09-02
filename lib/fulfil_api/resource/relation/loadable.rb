# frozen_string_literal: true

module FulfilApi
  class Resource
    class Relation
      # The {FulfilApi::Resource::Relation::Loadable} extends the relation by
      #   adding methods to load, reload and identify loaded resources from Fulfil's
      #   API endpoints.
      #
      # By default, all HTTP requests to Fulfil are delayed until they're directly
      #   or indirectly requested by the user of the gem. This way, we ensure that
      #   we only request data when we need to.
      module Loadable
        # Loads resources from Fulfil's API based on the current filters, fields, and limits
        #   if they haven't been loaded yet.
        #
        # Requires that {#name} is set; raises an exception if it's not.
        #
        # @return [true, false] True if the resources were loaded successfully.
        def load
          return true if loaded?

          if name.nil?
            raise FulfilApi::Resource::Relation::ModelNameMissing, "The model name is missing. Use #set to define it."
          end

          response = FulfilApi.client.put(
            "/model/#{name}/search_read",
            body: { filters: conditions, fields: fields, limit: request_limit }.compact_blank
          )

          @resources = response.map { |resource| @resource_klass.new(resource) }
          @loaded = true
        end

        # Checks whether the resources have been loaded to avoid repeated API calls when
        #   using enumerable methods.
        #
        # @return [true, false] True if the resources are already loaded.
        def loaded?
          @loaded
        end

        # Reloads the resources from Fulfil's API by resetting the {@loaded} flag.
        #
        # @return [true, false] True if the resources were successfully reloaded.
        def reload
          @loaded = false
          load
        end
      end
    end
  end
end
