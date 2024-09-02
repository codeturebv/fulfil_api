# frozen_string_literal: true

module FulfilApi
  class Resource
    # The {FulfilApi::Resource::Relation} class provides an abstraction for chaining multiple API operations.
    #
    # It allows handling a set of API resources in a uniform way, similar to
    #   ActiveRecord's query interface, enabling the user to build complex queries
    #   in a clean and reusable manner.
    class Relation
      include Enumerable

      attr_accessor :conditions, :fields, :name, :request_limit

      delegate_missing_to :all

      # Custom error class for missing model name. The model name is required to be
      #   able to build the API endpoint to perform the search/read HTTP request.
      class ModelNameMissing < Error; end

      # @param resource_klass [FulfilApi::Resource] The resource data model class.
      def initialize(resource_klass)
        @resource_klass = resource_klass

        @loaded = false
        @resources = []

        reset
      end

      # Loads and returns all resources from Fulfil's API. This method functions as a proxy,
      #   deferring the loading of resources until they are required, thus avoiding unnecessary
      #   HTTP requests.
      #
      # @return [Array<FulfilApi::Resource>] An array of loaded resource objects.
      def all
        load
        @resources
      end

      # The {#each} method allows iteration over the resources. If no block is given,
      #   it returns an Enumerator, enabling lazy evaluation and allowing for chaining
      #   without immediately triggering an API request.
      #
      # @yield [resource] Yields each resource object to the given block.
      # @return [Enumerator, self] Returns an Enumerator if no block is given; otherwise, returns self.
      def each(&block)
        all.each(&block)
      end

      # Finds the first resource that matches the given conditions.
      #
      # It constructs a query using the `where` method, limits the result to one record,
      #   and then returns the first result.
      #
      # @note Unlike the other methods in this module, `#find_by` will immediately trigger an
      #   HTTP request to retrieve the resource, rather than allowing for lazy evaluation.
      #
      # @param conditions [Array<String, String, String>] The filter conditions as required by Fulfil.
      # @return [FulfilApi::Resource, nil] The first resource that matches the conditions, or nil if no match is found.
      def find_by(conditions)
        where(conditions).limit(1).first
      end

      # Loads resources from Fulfil's API based on the current filters, fields, and limits
      #   if they haven't been loaded yet.
      #
      # Requires that {#name} is set; raises an exception if it's not.
      #
      # @return [true, false] True if the resources were loaded successfully.
      def load
        return true if loaded?

        raise ModelNameMissing, "The model name is missing. Use #set to define it." if name.nil?

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

      # Limits the number of resources returned by Fulfil's API. This is useful when only
      #   a specific number of resources are needed.
      #
      # @note If not specified, Fulfil's API defaults to returning up to 500 resources per call.
      #
      # @param value [Integer] The maximum number of resources to return.
      # @return [FulfilApi::Resource::Relation] A new {Relation} instance with the limit applied.
      def limit(value)
        clone.tap do |relation|
          relation.request_limit = value
        end
      end

      # Specifies the fields to include in the response from Fulfil's API. By default, only
      #   the ID is returned.
      #
      # Supports dot notation for nested data fields, though not all nested data may be available
      #   depending on the API's limitations.
      #
      # @example Requesting nested data fields
      #   FulfilApi::Resource.set(name: "sale.line").select("sale.reference").find_by(["id", "=", 10])
      #
      # @example Requesting additional fields
      #   FulfilApi::Resource.set(name: "sale.sale").select(:reference).find_by(["id", "=", 10])
      #
      # @param fields [Array<Symbol, String>] The fields to include in the response.
      # @return [FulfilApi::Resource::Relation] A new {Relation} instance with the selected fields.
      def select(*fields)
        clone.tap do |relation|
          relation.fields.concat(fields.map(&:to_s))
          relation.fields.uniq!
        end
      end

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

      # Reloads the resources from Fulfil's API by resetting the {@loaded} flag.
      #
      # @return [true, false] True if the resources were successfully reloaded.
      def reload
        @loaded = false
        load
      end

      # Resets any of the previously provided query conditions.
      #
      # @return [FulfilApi::Resource::Relation] The relation with cleared query conditions.
      def reset
        @conditions = []
        @fields = %w[id]
        @limit = nil

        self
      end

      # Adds filter conditions for querying Fulfil's API. Conditions should be formatted
      #   as arrays according to the Fulfil API documentation.
      #
      # @example Simple querying with conditions
      #   FulfilApi::Resource.set(name: "sale.line").where(["sale.reference", "=", "ORDER-123"])
      #
      # @todo Enhance the {#where} method to allow more natural and flexible queries.
      #
      # @param conditions [Array<String, String, String>] The filter conditions as required by Fulfil.
      # @return [FulfilApi::Resource::Relation] A new {Relation} instance with the conditions applied.
      def where(conditions)
        clone.tap do |relation|
          relation.conditions << conditions.flatten
          relation.conditions.uniq!
        end
      end
    end
  end
end
