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

      # Sorts the API resources returned by Fulfil's API.
      #
      # Fulfil expects the sort order as a list of field/direction pairs, applied in
      #   the order they're given. Both are accepted here, in whichever form reads
      #   best at the call site.
      #
      # @note If not specified, Fulfil falls back to the default order of the model.
      #
      # @example Sorting on a single field, ascending
      #   FulfilApi::Resource.set(model_name: "sale.sale").order(:create_date)
      #
      # @example Sorting on a single field, descending
      #   FulfilApi::Resource.set(model_name: "sale.sale").order(id: :desc)
      #
      # @example Sorting on multiple fields
      #   FulfilApi::Resource.set(model_name: "sale.sale").order(:create_date, number: :desc)
      #
      # @example Passing Fulfil's own format straight through
      #   FulfilApi::Resource.set(model_name: "sale.sale").order(["id", "DESC"])
      #
      # @param fields [Array<Symbol, String, Array, Hash>] The fields to sort on.
      # @return [FulfilApi::Relation] A new {Relation} instance with the sort order applied.
      def order(*fields)
        clone.tap do |relation|
          relation.request_order = (request_order + fields.flat_map { |field| normalize_order(field) }).uniq
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

      private

      # Turns a single argument to {#order} into the list of field/direction pairs
      #   that Fulfil's API expects.
      #
      # @param field [Symbol, String, Array, Hash] The field (and optional direction) to sort on.
      # @return [Array<Array<String>>] The normalized field/direction pairs.
      def normalize_order(field)
        case field
        when Hash then field.map { |name, direction| order_pair(name, direction) }
        when Array then [order_pair(*field)]
        else [order_pair(field)]
        end
      end

      # @param name [Symbol, String] The name of the field to sort on.
      # @param direction [Symbol, String] The direction to sort in.
      # @return [Array<String>] A single field/direction pair.
      # @raise [ArgumentError] When the direction is not one Fulfil understands.
      def order_pair(name, direction = :asc)
        direction = direction.to_s.upcase

        unless %w[ASC DESC].include?(direction)
          raise ArgumentError, "Unknown order direction #{direction.inspect}. Use :asc or :desc."
        end

        [name.to_s, direction]
      end
    end
  end
end
