# frozen_string_literal: true

require "test_helper"

module FulfilApi
  module Middleware
    class RateLimitCooldownTest < Minitest::Test
      def setup
        super
        @merchant_id = "merchant-#{SecureRandom.uuid}"
        @store = ActiveSupport::Cache::MemoryStore.new
        @client = build_client(@merchant_id, @store)
      end

      def test_is_off_by_default
        stub_fulfil_request(:get, status: 429, model: "sale.sale", id: 123)
        client = FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: @merchant_id))

        2.times { assert_raises(FulfilApi::HttpError::TooManyRequests) { client.get("sale.sale/123") } }

        assert_requested :get, %r{sale\.sale/123}, times: 2
      end

      def test_refuses_requests_locally_after_fulfil_rate_limited_one
        stub_fulfil_request(:get, status: 429, model: "sale.sale", id: 123)

        3.times { assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") } }

        assert_requested :get, %r{sale\.sale/123}, times: 1
      end

      def test_shares_the_cooldown_with_every_client_using_the_store
        stub_fulfil_request(:get, status: 429, model: "sale.sale", id: 123)
        assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        another_client = build_client(@merchant_id, @store)

        assert_raises(FulfilApi::HttpError::TooManyRequests) { another_client.get("sale.sale/123") }
        assert_requested :get, %r{sale\.sale/123}, times: 1
      end

      def test_tells_the_caller_how_long_the_cooldown_still_lasts
        stub_fulfil_request(:get, status: 429, model: "sale.sale", id: 123)
        assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        error = assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        assert_includes 1..RateLimitCooldown::DEFAULT_WAIT, error.response_headers["retry-after"].to_i
      end

      def test_cools_down_as_long_as_fulfil_asks
        stub_request(:get, /sale\.sale/).to_return(status: 429, body: "{}", headers: { "Retry-After" => "20" })
        assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        error = assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        assert_includes 19..20, error.response_headers["retry-after"].to_i
      end

      def test_never_cools_down_longer_than_the_maximum
        stub_request(:get, /sale\.sale/).to_return(status: 429, body: "{}", headers: { "Retry-After" => "600" })
        assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        error = assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        assert_operator error.response_headers["retry-after"].to_i, :<=, RateLimitCooldown::MAX_WAIT
      end

      def test_sends_requests_again_once_the_cooldown_has_passed
        stub_fulfil_request(:get, status: 429, model: "sale.sale", id: 123)
        assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        @store.clear
        stub_fulfil_request(:get, model: "sale.sale", id: 123, response: { id: 123 })

        assert_equal({ "id" => 123 }, @client.get("sale.sale/123"))
      end

      def test_cools_down_each_fulfil_instance_on_its_own
        stub_fulfil_request(:get, status: 429, model: "sale.sale", id: 123)
        assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        other_merchant_id = "merchant-#{SecureRandom.uuid}"
        stub_request(:get, %r{#{other_merchant_id}\.fulfil\.io/.*sale\.sale/123})
          .to_return(status: 200, body: { id: 123 }.to_json, headers: { "Content-Type" => "application/json" })

        assert_equal({ "id" => 123 }, build_client(other_merchant_id, @store).get("sale.sale/123"))
      end

      def test_cools_down_before_fulfil_rate_limits_once_the_budget_is_spent
        stub_request(:get, /sale\.sale/).to_return(
          status: 200, body: { id: 123 }.to_json,
          headers: { "Content-Type" => "application/json", "X-RateLimit-Remaining" => "0",
                     "X-RateLimit-Reset" => (Time.now.to_i + 2).to_s }
        )

        assert_equal({ "id" => 123 }, @client.get("sale.sale/123"))
        assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        assert_requested :get, %r{sale\.sale/123}, times: 1
      end

      def test_keeps_sending_while_the_budget_lasts
        stub_request(:get, /sale\.sale/).to_return(
          status: 200, body: { id: 123 }.to_json,
          headers: { "Content-Type" => "application/json", "X-RateLimit-Remaining" => "3",
                     "X-RateLimit-Reset" => (Time.now.to_i + 2).to_s }
        )

        2.times { @client.get("sale.sale/123") }

        assert_requested :get, %r{sale\.sale/123}, times: 2
      end

      def test_cools_down_until_fulfil_resets_its_rate_limit
        stub_request(:get, /sale\.sale/).to_return(
          status: 429, body: "{}",
          headers: { "X-RateLimit-Remaining" => "0", "X-RateLimit-Reset" => (Time.now.to_i + 9).to_s }
        )
        assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        error = assert_raises(FulfilApi::HttpError::TooManyRequests) { @client.get("sale.sale/123") }

        assert_includes 8..9, error.response_headers["retry-after"].to_i
      end

      private

      def build_client(merchant_id, store)
        FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: merchant_id, rate_limit_cooldown: store))
      end
    end
  end
end
