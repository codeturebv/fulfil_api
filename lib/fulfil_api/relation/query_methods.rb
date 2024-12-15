# frozen_string_literal: true

module FulfilApi
  class Relation
    # The {FulfilApi::Relation::QueryMethods} extends the relation by
    #   adding query methods to it.
    module QueryMethods
      # Finds the first resource that matches the given conditions.
      #
      # It constructs a query using the `where` method, limits the result to one record,
      #   and then returns the first result.
      #
      # @note Unlike the other methods in this module, `#find_by` will immediately trigger an
      #   HTTP request to retrieve the resource, rather than allowing for lazy evaluation.
      #
      # @param conditions [Array<String, String, String>] The filter conditions as required by Fulfil.
      # @return [FulfilApi::Resource, nil] The first resource that matches the conditions,
      #   or nil if no match is found.
      def find_by(conditions)
        where(conditions).limit(1).first
      end

      # Finds the first resource that matches the given conditions and raises
      #   when no resource is found.
      #
      # @see .find_by
      #
      # @param conditions [Array<String, String, String>] The filter conditions as required by Fulfil.
      # @return [FulfilApi::Resource] The first resource that matches the conditions
      # @raise [FulfilApi::Resource::NotFound]
      def find_by!(conditions)
        find_by(conditions) || raise(FulfilApi::Resource::NotFound, "Unable to find #{model_name} where #{conditions}")
      end

      # Limits the number of resources returned by Fulfil's API. This is useful when only
      #   a specific number of resources are needed.
      #
      # @note If not specified, Fulfil will assume a request limit of 500.
      #
      # @param value [Integer] The maximum number of resources to return.
      # @return [FulfilApi::Relation] A new {Relation} instance with the limit applied.
      def limit(value)
        clone.tap do |relation|
          relation.request_limit = value
        end
      end

      # Applies an offset to the API resources returned by Fulfil's API.
      #   This is useful when paginating over larger lists of API resources.
      #
      # @note If not specified, Fulfil will assume a request offset of 0.
      #
      # @param value [Integer] The page offset for the API request.
      # @return [FulfilApi::Relation] A new {Relation} instance with the offset applied.
      def offset(value)
        clone.tap do |relation|
          relation.request_offset = value
        end
      end

      # Specifies the fields to include in the response from Fulfil's API. By default, only
      #   the ID is returned.
      #
      # Supports dot notation for nested data fields, though not all nested data may be available
      #   depending on the API's limitations.
      #
      # @example Requesting nested data fields
      #   FulfilApi::Resource.set(model_name: "sale.line").select("sale.reference").find_by(["id", "=", 10])
      #
      # @example Requesting additional fields
      #   FulfilApi::Resource.set(model_name: "sale.sale").select(:reference).find_by(["id", "=", 10])
      #
      # @param fields [Array<Symbol, String>] The fields to include in the response.
      # @return [FulfilApi::Relation] A new {Relation} instance with the selected fields.
      def select(*fields)
        clone.tap do |relation|
          relation.fields.concat(fields.map(&:to_s))
          relation.fields.uniq!
        end
      end

      # Adds filter conditions for querying Fulfil's API. Conditions should be formatted
      #   as arrays according to the Fulfil API documentation.
      #
      # @example Simple querying with conditions
      #   FulfilApi::Resource.set(model_name: "sale.line").where(["sale.reference", "=", "ORDER-123"])
      #
      # @todo Enhance the {#where} method to allow more natural and flexible queries.
      #
      # @param conditions [Array<String, String, String>] The filter conditions as required by Fulfil.
      # @return [FulfilApi::Relation] A new {Relation} instance with the conditions applied.
      def where(conditions)
        clone.tap do |relation|
          relation.conditions << conditions
          relation.conditions.uniq!
        end
      end
    end
  end
end
