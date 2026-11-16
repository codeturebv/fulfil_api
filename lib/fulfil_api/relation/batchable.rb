# frozen_string_literal: true

module FulfilApi
  class Relation
    # The {FulfilApi::Relation::Batchable} module includes a set of
    #   helper/query methods that queries resources in Fulfil in batches.
    module Batchable
      # The `RetryLimitExceeded` is raised when the maximum number of retry requests has
      #   been exceeded and we have no other option to cut off the retry mechanism.
      class RetryLimitExceeded < Error; end

      # How long {#in_batches} waits before its first retry after a 429. Every next retry
      #   waits twice as long, up to {RETRY_MAX_WAIT}.
      RETRY_BASE_WAIT = 0.5

      # The longest {#in_batches} waits between two retries, also when Fulfil asks for longer.
      RETRY_MAX_WAIT = 30

      # Pauses the current thread. Separate from {#in_batches} so the wait can be stubbed.
      #
      # @param seconds [Numeric]
      # @return [void]
      def self.pause(seconds)
        sleep(seconds)
      end

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
      #   (TooManyRequests) HTTP error to ensure the lookup can be completed. It waits until
      #   Fulfil's rate limit resets (see {FulfilApi::RateLimit.wait}), or backs off
      #   exponentially (with jitter) when Fulfil doesn't say, so a rate limited lookup
      #   doesn't keep hammering Fulfil.
      #
      # @param of [Integer] The maximum number of resources in a batch.
      # @param retries [Symbol, Integer] The maximum number of retries before raising.
      # @yield [FulfilApi::Relation] Yields FulfilApi::Relation
      #   objects to work with a batch of records.
      # @return [FulfilApi::Relation]
      def in_batches(of: 500, retries: :unlimited) # rubocop:disable Metrics/MethodLength
        current_retry = 0
        current_offset = request_offset.presence || 0
        batch_size = of

        loop do
          batch_relation = dup.offset(current_offset * batch_size).limit(batch_size)
          batch_relation.load

          yield(batch_relation)

          break unless batch_relation.size == batch_size

          current_offset += 1
          current_retry = 0 # Reset the retries back to the default
        rescue FulfilApi::HttpError::TooManyRequests => e
          ensure_retry_allowed!(current_retry, retries)

          current_retry += 1
          Batchable.pause(retry_wait(current_retry, e))
          retry
        end

        self
      end

      private

      # @param current_retry [Integer] The number of retries so far.
      # @param retries [Symbol, Integer] The maximum number of retries.
      # @raise [RetryLimitExceeded] When no retries are left.
      # @return [void]
      def ensure_retry_allowed!(current_retry, retries)
        return if retries == :unlimited || current_retry <= retries

        raise RetryLimitExceeded, "the maximum number of #{retries} retries has been reached."
      end

      # @param attempt [Integer] The number of the upcoming retry, starting at 1.
      # @param error [FulfilApi::HttpError::TooManyRequests] The rate limit error of Fulfil.
      # @return [Numeric] The number of seconds to wait before retrying.
      def retry_wait(attempt, error)
        requested_wait = FulfilApi::RateLimit.wait(error.response_headers)
        return [requested_wait, RETRY_MAX_WAIT].min if requested_wait

        backoff = [RETRY_BASE_WAIT * (2**(attempt - 1)), RETRY_MAX_WAIT].min

        # Wait somewhere between half and the full backoff, so threads that were rate limited at
        #   the same moment don't all retry at the same moment too.
        backoff * rand(0.5..1.0)
      end
    end
  end
end
