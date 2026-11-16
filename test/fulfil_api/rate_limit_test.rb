# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class RateLimitTest < Minitest::Test
    def setup
      super
      @now = Time.at(1_794_828_164)
    end

    def test_reads_the_remaining_tokens_whatever_the_casing
      assert_equal 24, RateLimit.remaining({ "X-RateLimit-Remaining" => "24" })
      assert_nil RateLimit.remaining({})
    end

    def test_waits_until_the_rate_limit_resets
      assert_equal 2, RateLimit.wait({ "x-ratelimit-reset" => "1794828166" }, now: @now)
    end

    def test_waits_at_least_a_second_when_the_reset_is_now
      assert_equal 1, RateLimit.wait({ "x-ratelimit-reset" => "1794828164" }, now: @now)
    end

    def test_prefers_retry_after_over_the_reset
      assert_equal 7, RateLimit.wait({ "Retry-After" => "7", "x-ratelimit-reset" => "1794828166" }, now: @now)
    end

    def test_does_not_know_how_long_to_wait_without_either_header
      assert_nil RateLimit.wait({ "content-type" => "application/json" }, now: @now)
      assert_nil RateLimit.wait(nil, now: @now)
    end
  end
end
