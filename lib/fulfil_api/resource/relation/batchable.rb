# frozen_string_literal: true

module FulfilApi
  class Resource
    class Relation
      # The {FulfilApi::Resource::Relation::Batchable} module includes a set of
      #   helper/query methods that queries resources in Fulfil in batches.
      module Batchable
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
        # @yield [FulfilApi::Resource::Relation] Yields FulfilApi::Resource::Relation
        #   objects to work with a batch of records.
        # @return [FulfilApi::Resource::Relation]
        def in_batches(of: 500) # rubocop:disable Metrics/MethodLength
          current_offset = request_offset.presence || 0
          batch_size = of

          loop do
            batch_relation = dup.offset(current_offset * batch_size).limit(batch_size)
            batch_relation.load

            yield(batch_relation)

            break unless batch_relation.size == batch_size

            current_offset += 1
          rescue FulfilApi::Error => e
            retry if e.details[:response_status] == 429
          end

          self
        end
      end
    end
  end
end
