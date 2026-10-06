# frozen_string_literal: true

require "test_helper"
require "faulty"
require "minitest/mock"

module FulfilApi
  module Middleware
    class CircuitBreakerTest < Minitest::Test
      def setup
        @merchant_id = "merchant-#{SecureRandom.uuid}"
        @faulty = Faulty.new(
          storage: Faulty::Storage::Memory.new,
          listeners: [],
          circuit_defaults: { sample_threshold: 2, rate_threshold: 0.5, cool_down: 30 }
        )
        @client = build_client(@merchant_id)
      end

      def test_is_off_by_default
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)
        client = FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: @merchant_id))

        3.times { assert_raises(FulfilApi::HttpError) { client.get("sale.sale/123") } }

        assert_requested :get, %r{sale\.sale/123}, times: 3
      end

      def test_raises_the_original_error_while_the_circuit_is_closed
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)

        2.times { assert_raises(FulfilApi::HttpError::ServiceUnavailable) { @client.get("sale.sale/123") } }
      end

      def test_skips_the_fulfil_instance_once_the_circuit_opened
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)

        2.times { assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") } }
        error = assert_raises(FulfilApi::CircuitOpen) { @client.get("sale.sale/123") }

        assert_kind_of FulfilApi::Error, error
        assert_empty error.details
        assert_requested :get, %r{sale\.sale/123}, times: 2
      end

      def test_counts_timeouts_and_dropped_connections
        stubbed_request_for(:get, model: "sale.sale", id: 123).to_timeout
        stubbed_request_for(:get, model: "sale.sale", id: 456).to_raise(Errno::ECONNREFUSED)

        assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") }
        assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/456") }

        assert_raises(FulfilApi::CircuitOpen) { @client.get("sale.sale/123") }
      end

      def test_counts_a_retried_request_as_one_failure
        stubbed_request_for(:get, model: "sale.sale", id: 123).to_timeout

        assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") }

        assert_requested :get, %r{sale\.sale/123}, times: 2
        refute_predicate circuit_status_for(@merchant_id), :open?
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

        assert_predicate circuit_status_for(@merchant_id), :open?
        refute_predicate circuit_status_for(other_merchant_id), :open?
        assert_raises(FulfilApi::HttpError::ServiceUnavailable) { build_client(other_merchant_id).get("sale.sale/123") }
      end

      def test_lets_a_request_through_after_the_cool_down
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)

        2.times { assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") } }

        stub_fulfil_request(:get, model: "sale.sale", id: 123)

        Faulty.stub(:current_time, Faulty.current_time + 31) do
          @client.get("sale.sale/123")

          assert_predicate circuit_status_for(@merchant_id), :closed?
        end
      end

      def test_shares_the_circuit_with_the_tpl_client_of_the_same_instance
        stub_fulfil_request(:get, status: 503, model: "sale.sale", id: 123)
        stub_request(:get, %r{fulfil.io/services/3pl/v1/inbound-transfers})

        2.times { assert_raises(FulfilApi::HttpError) { @client.get("sale.sale/123") } }

        tpl_client = FulfilApi::TplClient.new(
          FulfilApi::Configuration.new(merchant_id: @merchant_id, tpl: { auth_token: "token" },
                                       circuit_breaker: @faulty)
        )

        assert_raises(FulfilApi::CircuitOpen) { tpl_client.get("inbound-transfers") }
        assert_not_requested :get, /inbound-transfers/
      end

      private

      def build_client(merchant_id)
        FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: merchant_id, circuit_breaker: @faulty))
      end

      def circuit_status_for(merchant_id)
        @faulty.circuit("fulfil_api:#{merchant_id}.fulfil.io").status
      end
    end
  end
end
