# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class ClientTest < Minitest::Test
    def setup
      @merchant_id = "merchant-#{SecureRandom.uuid}"

      @client = FulfilApi::Client.new(
        FulfilApi::Configuration.new(merchant_id: @merchant_id, api_version: @version)
      )
    end

    def test_relative_path_expansion
      stub_fulfil_request(:get, model: "sale.sale", id: 123)

      @client.get("sale.sale/123")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/api/v2/sale.sale/123"
    end

    def test_removal_of_duplicate_slashes_from_request_path
      stub_fulfil_request(:get, model: "sale.sale", id: 123)

      @client.get("/sale.sale/123")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/api/v2/sale.sale/123"
    end

    def test_inclusion_of_merchant_id
      stub_fulfil_request(:get, model: "sale.sale", id: 123)

      @client.get("/sale.sale/123")

      assert_requested :get, /#{@merchant_id}/i
    end

    def test_inclusion_of_version_number
      stub_fulfil_request(:get, model: "sale.sale", id: 123)

      version_number = %w[v1 v2 v3 v4 v5].sample

      client = FulfilApi::Client.new(
        FulfilApi::Configuration.new(merchant_id: @merchant_id, api_version: version_number)
      )

      client.get("/sale.sale/123")

      assert_requested :get, /#{version_number}/i
    end

    def test_reraising_of_http_errors
      stub_fulfil_request(:get, status: 422, response: { error: "something went wrong" })

      error =
        assert_raises FulfilApi::Error do
          @client.get("sale.sale/123")
        end

      assert_equal 422, error.details[:response_status]
      assert_equal({ error: "something went wrong" }.to_json, error.details[:response_body])
    end

    def test_put_request_without_body
      stub_fulfil_request(:put)

      sale_id = SecureRandom.uuid
      @client.put("sale.sale/#{sale_id}")

      assert_requested :put, %r{sale\.sale/#{sale_id}}i, times: 1 do |request|
        assert_empty request.body
      end
    end

    def test_forwarding_of_optional_request_body_for_put_requests
      stub_fulfil_request(:put)

      sale_id = SecureRandom.uuid
      @client.put("sale.sale/#{sale_id}", body: { status: "fulfilled" })

      assert_requested :put, %r{sale\.sale/#{sale_id}}i, times: 1 do |request|
        assert_equal({ "status" => "fulfilled" }, JSON.parse(request.body))
      end
    end

    def test_forwarding_of_required_request_body_for_post_requests
      stub_fulfil_request(:post)

      sale_id = SecureRandom.uuid
      @client.post("sale.sale", body: { id: sale_id })

      assert_requested :post, /sale\.sale/i do |request|
        assert_equal({ "id" => sale_id }, JSON.parse(request.body))
      end
    end

    def test_forwarding_of_optional_url_parameters_for_get_requests
      stub_fulfil_request(:get)

      @client.get("sale.sale/123")

      assert_requested :get, %r{sale\.sale/123}i, times: 1

      @client.get("sale.sale/123", url_parameters: { page: 1 })

      assert_requested :get, %r{sale\.sale/123\?page=1}i, times: 1
    end

    def test_performance_of_delete_request
      stub_fulfil_request(:delete)

      @client.delete("sale.sale/123")

      assert_requested :delete, %r{sale\.sale/123}i
    end
  end
end
