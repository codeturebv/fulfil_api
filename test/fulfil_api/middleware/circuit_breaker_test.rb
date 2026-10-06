# frozen_string_literal: true

require "test_helper"

module FulfilApi
  module Middleware
    class CircuitBreakerTest < Minitest::Test
      def setup
        @merchant_id = "merchant-#{SecureRandom.uuid}"
        @store = ActiveSupport::Cache::MemoryStore.new
        @client = build_client(@merchant_id)
      end

      def test_is_off_by_default
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)
        client = FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: @merchant_id))

        3.times { assert_raises(FulfilApi::HttpError) { client.get("sale.sale/123") } }

        assert_requested :get, %r{sale\.sale/123}, times: 3
      end

      def test_opens_after_the_failure_threshold
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)

        2.times { assert_raises(FulfilApi::HttpError::ServiceUnavailable) { @client.get("sale.sale/123") } }
        error = assert_raises(FulfilApi::Circuit::Open) { @client.get("sale.sale/123") }

        assert_kind_of FulfilApi::Error, error
        assert_empty error.details
        assert_requested :get, %r{sale\.sale/123}, times: 2
      end

      def test_counts_timeouts_and_dropped_connections
        stubbed_request_for(:get, model: "sale.sale", id: 123).to_timeout
        stubbed_request_for(:get, model: "sale.sale", id: 456).to_raise(Errno::ECONNREFUSED)

        assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") }
        assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/456") }

        assert_raises(FulfilApi::Circuit::Open) { @client.get("sale.sale/123") }
      end

      def test_counts_a_retried_request_as_one_failure
        stubbed_request_for(:get, model: "sale.sale", id: 123).to_timeout

        assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") }

        assert_requested :get, %r{sale\.sale/123}, times: 2
        refute_predicate circuit_for(@merchant_id), :open?
      end

      def test_ignores_client_errors
        stub_fulfil_request(:get, status: 404, model: "sale.sale", id: 123)

        3.times { assert_raises(FulfilApi::HttpError::NotFound) { @client.get("sale.sale/123") } }

        assert_requested :get, %r{sale\.sale/123}, times: 3
      end

      def test_keeps_a_circuit_per_fulfil_instance
        other_merchant_id = "merchant-#{SecureRandom.uuid}"
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)

        2.times { assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") } }

        assert_predicate circuit_for(@merchant_id), :open?
        refute_predicate circuit_for(other_merchant_id), :open?
        assert_raises(FulfilApi::HttpError::ServiceUnavailable) { build_client(other_merchant_id).get("sale.sale/123") }
      end

      def test_closes_again_after_the_cool_down
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)
        client = build_client(@merchant_id, cool_down: 0.05)

        2.times { assert_raises(FulfilApi::HttpError) { client.get("sale.sale/123") } }
        assert_raises(FulfilApi::Circuit::Open) { client.get("sale.sale/123") }

        sleep 0.1

        assert_raises(FulfilApi::HttpError::ServiceUnavailable) { client.get("sale.sale/123") }
      end

      def test_shares_the_circuit_with_the_tpl_client_of_the_same_instance
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)
        stub_request(:get, %r{fulfil.io/services/3pl/v1/inbound-transfers})

        2.times { assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") } }

        tpl_client = FulfilApi::TplClient.new(
          FulfilApi::Configuration.new(
            merchant_id: @merchant_id, tpl: { auth_token: "token" }, circuit_breaker: circuit_breaker_options
          )
        )

        assert_raises(FulfilApi::Circuit::Open) { tpl_client.get("inbound-transfers") }
        assert_not_requested :get, /inbound-transfers/
      end

      private

      def build_client(merchant_id, **options)
        FulfilApi::Client.new(
          FulfilApi::Configuration.new(merchant_id: merchant_id, circuit_breaker: circuit_breaker_options(**options))
        )
      end

      def circuit_breaker_options(**options)
        { failure_threshold: 2, window: 60, cool_down: 30, store: @store }.merge(options)
      end

      def circuit_for(merchant_id)
        FulfilApi::Circuit.new("#{merchant_id}.fulfil.io", **circuit_breaker_options)
      end
    end
  end
end
