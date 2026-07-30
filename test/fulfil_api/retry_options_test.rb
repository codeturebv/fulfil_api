# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class RetryOptionsTest < Minitest::Test
    def setup
      @merchant_id = "merchant-#{SecureRandom.uuid}"
      @client = build_client
    end

    def test_retries_a_search_read_after_a_dropped_connection
      stubbed_request_for(:put, model: "sale.sale", suffix: "search_read")
        .to_raise(Errno::ECONNRESET).then
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type": "application/json" })

      assert_empty @client.put("/model/sale.sale/search_read", body: { filters: [] })
      assert_requested :put, %r{sale\.sale/search_read}, times: 2
    end

    def test_retries_a_search_count_after_a_timeout
      stubbed_request_for(:put, model: "sale.sale", suffix: "search_count")
        .to_timeout.then
        .to_return(status: 200, body: 3.to_json, headers: { "Content-Type": "application/json" })

      assert_equal 3, @client.put("/model/sale.sale/search_count", body: { filters: [] })
      assert_requested :put, %r{sale\.sale/search_count}, times: 2
    end

    def test_retries_a_get_request_on_any_endpoint
      stubbed_request_for(:get, model: "sale.sale", id: 123)
        .to_raise(Errno::ECONNRESET).then
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type": "application/json" })

      @client.get("sale.sale/123")

      assert_requested :get, %r{sale\.sale/123}, times: 2
    end

    def test_does_not_retry_a_put_request_that_writes
      stubbed_request_for(:put, model: "stock.shipment.out", suffix: "hold").to_timeout

      assert_raises(FulfilApi::HttpError) { @client.put("/model/stock.shipment.out/hold", body: [[1], "note"]) }
      assert_requested :put, %r{stock\.shipment\.out/hold}, times: 1
    end

    def test_does_not_retry_a_post_request
      stubbed_request_for(:post, model: "sale.sale").to_raise(Errno::ECONNRESET)

      assert_raises(FulfilApi::HttpError) { @client.post("/model/sale.sale", body: { reference: "1" }) }
      assert_requested :post, /sale\.sale/, times: 1
    end

    def test_does_not_retry_an_error_response
      stub_fulfil_request(:put, status: 503, model: "sale.sale", suffix: "search_read")

      assert_raises(FulfilApi::HttpError::ServiceUnavailable) do
        @client.put("/model/sale.sale/search_read", body: { filters: [] })
      end
      assert_requested :put, %r{sale\.sale/search_read}, times: 1
    end

    def test_stops_after_the_maximum_number_of_retries
      stubbed_request_for(:put, model: "sale.sale", suffix: "search_read").to_raise(Errno::ECONNRESET)

      client = build_client(retry_options: { max_retries: 2 })

      assert_raises(FulfilApi::HttpError) { client.put("/model/sale.sale/search_read", body: { filters: [] }) }
      assert_requested :put, %r{sale\.sale/search_read}, times: 3
    end

    def test_retries_a_write_endpoint_when_configured
      stubbed_request_for(:put, model: "stock.shipment.out", suffix: "hold")
        .to_timeout.then
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type": "application/json" })

      client = build_client(retry_options: { requests: { put: [%r{/hold\z}] } })
      client.put("/model/stock.shipment.out/hold", body: [[1], "note"])

      assert_requested :put, %r{stock\.shipment\.out/hold}, times: 2
    end

    def test_resends_the_request_body_on_a_retry
      stubbed_request_for(:put, model: "sale.sale", suffix: "search_read")
        .to_raise(Errno::ECONNRESET).then
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type": "application/json" })

      @client.put("/model/sale.sale/search_read", body: { filters: [["id", "=", 1]] })

      assert_requested :put, %r{sale\.sale/search_read}, body: { filters: [["id", "=", 1]] }.to_json, times: 2
    end

    def test_retries_requests_of_the_tpl_client
      stub_request(:get, %r{fulfil.io/services/3pl/v1/inbound-transfers})
        .to_raise(Errno::ECONNRESET).then
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type": "application/json" })

      tpl_client = FulfilApi::TplClient.new(
        FulfilApi::Configuration.new(merchant_id: @merchant_id, tpl: { auth_token: "token" })
      )
      tpl_client.get("inbound-transfers")

      assert_requested :get, /inbound-transfers/, times: 2
    end

    private

    def build_client(**)
      FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: @merchant_id, **))
    end
  end
end
