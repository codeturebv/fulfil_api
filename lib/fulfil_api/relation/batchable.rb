# frozen_string_literal: true

module FulfilApi
  class Relation
    # The {FulfilApi::Relation::Batchable} module includes a set of
    #   helper/query methods that queries resources in Fulfil in batches.
    module Batchable
      # The `RetryLimitExceeded` is raised when the maximum number of retry requests has
      #   been exceeded and we have no other option to cut off the retry mechanism.
      class RetryLimitExceeded < Error; end

      # The {#find_each} is a shorthand for iterating over individual API resources
      #   in a memory effective way.
      #
      # Under the hood, it uses the {#in_batches} to find API resources in batches
      #   and process them efficiently.
      #
      # @example find all resources
      #
      #   FulfilApi::Resource.set(model_name: "sale.sale").find_each do |sales_order|
      #     process_sales_order(sales_order)
      #   end
      #
      # @param batch_size [Integer] The default batch forwarded to the {#in_batches} method.
      # @yield [FulfilApi::Resource] An individual API resource.
      # @return [FulfilApi::Relation]
      def find_each(batch_size: 500, &block)
        in_batches(of: batch_size) do |batch|
          batch.each(&block)
        end
      end

      # Finds API resources in batches. Defaults to the maximum number of resources
      #   Fulfil's API endpoints will return (500 resources).
      #
      # @example find resources in batches of 10.
      #
      #   FulfilApi::Resource.set(model_name: "sale.sale").in_batches(of: 10) do |batch|
      #     batch.each do |sales_order|
      #       process_sales_order(sales_order)
      #     end
      #   end
      #
      # @note the {#in_batches} automatically retries when it encounters a 429
      #   (TooManyRequests) HTTP error to ensure the lookup can be completed.
      #
      # @param of [Integer] The maximum number of resources in a batch.
      # @param retries [Integer] The maximum number of retries before raising.
      # @yield [FulfilApi::Relation] Yields FulfilApi::Relation
      #   objects to work with a batch of records.
      # @return [FulfilApi::Relation]
      def in_batches(of: 500, retries: 5) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        current_retry = 0
        current_offset = request_offset.presence || 0
        batch_size = of

        loop do
          batch_relation = dup.offset(current_offset * batch_size).limit(batch_size)
          batch_relation.load

          yield(batch_relation)

          break unless batch_relation.size == batch_size

          current_offset += 1
        rescue FulfilApi::Error => e
          if e.details[:response_status] == 429
            if current_retry > retries
              raise RetryLimitExceeded, "the maximum number of #{retries} retries has been reached."
            end

            current_retry += 1
            retry
          end

          raise e
        end

        self
      end
    end
  end
end
