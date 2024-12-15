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

      # Insert the {FulfilApi::Resource::Relation} modules after the inclusion of
      #   standard Ruby module extensions. This ensures our modules win when there
      #   is any conflicting method. An example of this is the {#count} method.
      include Countable
      include Batchable
      include Loadable
      include Naming
      include QueryMethods

      attr_accessor :conditions, :fields, :model_name, :request_limit, :request_offset

      delegate_missing_to :all

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

      # Resets any of the previously provided query conditions.
      #
      # @return [FulfilApi::Resource::Relation] The relation with cleared query conditions.
      def reset
        @conditions = []
        @fields = %w[id]
        @request_limit = nil
        @request_offset = nil

        self
      end
    end
  end
end
