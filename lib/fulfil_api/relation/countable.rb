# frozen_string_literal: true

module FulfilApi
  class Relation
    # The {FulfilApi::Relation::Countable} extends the relation by
    #   adding a method to count the records within a given context.
    module Countable
      # Finds the exact number of API resources in Fulfil.
      #
      # @note It takes into account the query conditions and can be used to find
      #   the count of a subset of resources.
      #
      # @note The {#count} directly triggers an HTTP request to Fulfil but the
      #   return value is cached. When you want to recount, use {#recount}.
      #
      # @return [Integer]
      def count
        raise FulfilApi::Resource::ModelNameMissing if model_name.nil?

        @count ||= FulfilApi.client.put(
          "/model/#{model_name}/search_count",
          body: { filters: conditions }.compact_blank
        )
      end

      # Checks if the relation has already been counted.
      #
      # @return [true, false]
      def counted?
        @count
      end

      # Recounts the exact number of API resources in Fulfil.
      #
      # @note Under the hood, it uses the {#count} method by resetting the cached
      #   value and calling {#count} again.
      #
      # @return [Integer]
      def recount
        @count = nil
        count
      end
    end
  end
end
