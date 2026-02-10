# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class TplClientTest < Minitest::Test
    def setup
      @merchant_id = "merchant-#{SecureRandom.uuid}"
      @auth_token = "tpl-token-#{SecureRandom.uuid}"

      @configuration = FulfilApi::Configuration.new(
        merchant_id: @merchant_id,
        tpl: { auth_token: @auth_token }
      )

      @client = FulfilApi::TplClient.new(@configuration)
    end

    def test_uses_tpl_specific_merchant_id_when_provided
      tpl_merchant_id = "tpl-merchant-#{SecureRandom.uuid}"

      configuration = FulfilApi::Configuration.new(
        merchant_id: @merchant_id,
        tpl: { auth_token: @auth_token, merchant_id: tpl_merchant_id }
      )

      client = FulfilApi::TplClient.new(configuration)

      stub_fulfil_tpl_request(:get, path: "shipments")
      client.get("shipments")

      assert_requested :get, "https://#{tpl_merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    def test_falls_back_to_global_merchant_id
      stub_fulfil_tpl_request(:get, path: "shipments")

      @client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    def test_defaults_to_v1_api_version
      stub_fulfil_tpl_request(:get, path: "shipments")

      @client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    def test_uses_custom_api_version_when_provided
      configuration = FulfilApi::Configuration.new(
        merchant_id: @merchant_id,
        tpl: { auth_token: @auth_token, api_version: "v2" }
      )

      client = FulfilApi::TplClient.new(configuration)

      stub_fulfil_tpl_request(:get, path: "shipments")
      client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v2/shipments"
    end

    def test_builds_correct_request_path
      stub_fulfil_tpl_request(:get, path: "shipments")

      @client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    def test_squeezes_duplicate_slashes_in_path
      stub_fulfil_tpl_request(:get, path: "shipments")

      @client.get("/shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    def test_includes_bearer_token_in_requests
      stub_fulfil_tpl_request(:get, path: "shipments")

      @client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments" do |request|
        assert_equal "Bearer #{@auth_token}", request.headers["Authorization"]
      end
    end

    def test_get_request
      stub_fulfil_tpl_request(:get, path: "shipments", response: [{ "id" => 1 }])

      result = @client.get("shipments")

      assert_equal [{ "id" => 1 }], result
    end

    def test_get_request_with_query_params
      stub_fulfil_tpl_request(:get, path: "shipments")

      @client.get("shipments", page: 1, per_page: 25)

      assert_requested :get, %r{services/3pl/v1/shipments\?page=1&per_page=25}i
    end

    def test_get_request_filters_blank_query_params
      stub_fulfil_tpl_request(:get, path: "shipments")

      @client.get("shipments", page: 1, status: nil, name: "")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments?page=1"
    end

    def test_post_request
      stub_fulfil_tpl_request(:post, path: "shipments")

      @client.post("shipments", { tracking_number: "ABC123" })

      assert_requested :post, %r{services/3pl/v1/shipments}i do |request|
        assert_equal({ "tracking_number" => "ABC123" }, JSON.parse(request.body))
      end
    end

    def test_put_request
      stub_fulfil_tpl_request(:put, path: "shipments", id: "1")

      @client.put("shipments/1", { status: "shipped" })

      assert_requested :put, %r{services/3pl/v1/shipments/1}i do |request|
        assert_equal({ "status" => "shipped" }, JSON.parse(request.body))
      end
    end

    def test_patch_request
      stub_fulfil_tpl_request(:patch, path: "shipments", id: "1")

      @client.patch("shipments/1", { status: "delivered" })

      assert_requested :patch, %r{services/3pl/v1/shipments/1}i do |request|
        assert_equal({ "status" => "delivered" }, JSON.parse(request.body))
      end
    end

    def test_delete_request
      stub_fulfil_tpl_request(:delete, path: "shipments", id: "1")

      @client.delete("shipments/1")

      assert_requested :delete, %r{services/3pl/v1/shipments/1}i
    end

    def test_reraising_of_http_errors
      stub_fulfil_tpl_request(:get, path: "shipments", status: 422, response: { error: "something went wrong" })

      error =
        assert_raises FulfilApi::Error do
          @client.get("shipments")
        end

      assert_equal 422, error.details[:response_status]
      assert_equal({ error: "something went wrong" }.to_json, error.details[:response_body])
    end
  end
end
