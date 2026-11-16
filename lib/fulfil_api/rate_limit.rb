# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::RateLimit} reads Fulfil's rate limit headers.
  #
  # Fulfil reports its rate limit on every response: `x-ratelimit-limit` (the token budget),
  #   `x-ratelimit-remaining` (the tokens left) and `x-ratelimit-reset` (the epoch second the
  #   budget resets at). The budget is shared by every request made with the same credentials.
  module RateLimit
    class << self
      # @param headers [Hash, nil] The response headers of Fulfil.
      # @return [Integer, nil] The tokens left in the budget, or nil when Fulfil didn't say.
      def remaining(headers)
        value = header(headers, "x-ratelimit-remaining")
        value.to_i if value.to_s.match?(/\A\d+\z/)
      end

      # The seconds to wait before sending another request: as long as Fulfil's `Retry-After`
      #   asks, or else until the budget resets according to `x-ratelimit-reset`.
      #
      # @param headers [Hash, nil] The response headers of Fulfil.
      # @param now [Time]
      # @return [Integer, nil] The seconds to wait, or nil when Fulfil didn't say.
      def wait(headers, now: Time.now)
        retry_after(headers, now) || until_reset(headers, now)
      end

      private

      # @return [String, nil] The value of the header, whatever the casing of its name.
      def header(headers, name)
        headers.to_h.find { |key, _| key.to_s.casecmp?(name) }&.last
      end

      def retry_after(headers, now)
        value = header(headers, "retry-after").to_s
        return if value.empty?
        return value.to_i if value.match?(/\A\d+\z/)

        [(Time.httpdate(value) - now).ceil, 0].max
      rescue ArgumentError
        nil
      end

      def until_reset(headers, now)
        value = header(headers, "x-ratelimit-reset").to_s
        return unless value.match?(/\A\d+\z/)

        # The reset is given in whole seconds, so wait at least one to not retry inside the
        #   second that was just rate limited.
        [value.to_i - now.to_i, 1].max
      end
    end
  end
end
