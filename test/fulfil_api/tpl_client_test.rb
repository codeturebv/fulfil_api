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

    def teardown
      FulfilApi.configuration = FulfilApi::Configuration.new
    end

    # -- Configuration Tests --

    def test_raises_error_when_auth_token_is_missing
      configuration = FulfilApi::Configuration.new(merchant_id: @merchant_id, tpl: {})

      assert_raises FulfilApi::TplClient::ConfigurationError do
        FulfilApi::TplClient.new(configuration)
      end
    end

    def test_raises_error_when_tpl_config_is_nil
      configuration = FulfilApi::Configuration.new(merchant_id: @merchant_id)

      assert_raises FulfilApi::TplClient::ConfigurationError do
        FulfilApi::TplClient.new(configuration)
      end
    end

    def test_raises_error_when_merchant_id_is_missing
      configuration = FulfilApi::Configuration.new(tpl: { auth_token: @auth_token })

      assert_raises FulfilApi::TplClient::ConfigurationError do
        FulfilApi::TplClient.new(configuration)
      end
    end

    def test_uses_tpl_specific_merchant_id_when_provided
      tpl_merchant_id = "tpl-merchant-#{SecureRandom.uuid}"

      configuration = FulfilApi::Configuration.new(
        merchant_id: @merchant_id,
        tpl: { auth_token: @auth_token, merchant_id: tpl_merchant_id }
      )

      client = FulfilApi::TplClient.new(configuration)

      stub_tpl_request(:get, merchant_id: tpl_merchant_id)
      client.get("shipments")

      assert_requested :get, "https://#{tpl_merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    # -- API Version Tests --

    def test_defaults_to_v1_api_version
      stub_tpl_request(:get, merchant_id: @merchant_id)

      @client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    def test_uses_custom_api_version_when_provided
      configuration = FulfilApi::Configuration.new(
        merchant_id: @merchant_id,
        tpl: { auth_token: @auth_token, api_version: "v2" }
      )

      client = FulfilApi::TplClient.new(configuration)

      stub_request(:get, %r{#{@merchant_id}\.fulfil\.io/services/3pl/v2}i)
        .and_return(status: 200, body: "{}".to_json, headers: { "Content-Type": "application/json" })

      client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v2/shipments"
    end

    def test_falls_back_to_global_merchant_id
      stub_tpl_request(:get, merchant_id: @merchant_id)

      @client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    # -- Request Path Tests --

    def test_builds_correct_request_path
      stub_tpl_request(:get, merchant_id: @merchant_id)

      @client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    def test_squeezes_duplicate_slashes_in_path
      stub_tpl_request(:get, merchant_id: @merchant_id)

      @client.get("/shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments"
    end

    # -- Authentication Tests --

    def test_includes_bearer_token_in_requests
      stub_tpl_request(:get, merchant_id: @merchant_id)

      @client.get("shipments")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments" do |request|
        assert_equal "Bearer #{@auth_token}", request.headers["Authorization"]
      end
    end

    # -- HTTP Method Tests --

    def test_get_request
      stub_tpl_request(:get, merchant_id: @merchant_id, response: [{ "id" => 1 }])

      result = @client.get("shipments")

      assert_equal [{ "id" => 1 }], result
    end

    def test_get_request_with_query_params
      stub_tpl_request(:get, merchant_id: @merchant_id)

      @client.get("shipments", page: 1, per_page: 25)

      assert_requested :get, %r{services/3pl/v1/shipments\?page=1&per_page=25}i
    end

    def test_get_request_filters_blank_query_params
      stub_tpl_request(:get, merchant_id: @merchant_id)

      @client.get("shipments", page: 1, status: nil, name: "")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/shipments?page=1"
    end

    def test_post_request
      stub_tpl_request(:post, merchant_id: @merchant_id)

      @client.post("shipments", { tracking_number: "ABC123" })

      assert_requested :post, %r{services/3pl/v1/shipments}i do |request|
        assert_equal({ "tracking_number" => "ABC123" }, JSON.parse(request.body))
      end
    end

    def test_put_request
      stub_tpl_request(:put, merchant_id: @merchant_id)

      @client.put("shipments/1", { status: "shipped" })

      assert_requested :put, %r{services/3pl/v1/shipments/1}i do |request|
        assert_equal({ "status" => "shipped" }, JSON.parse(request.body))
      end
    end

    def test_patch_request
      stub_tpl_request(:patch, merchant_id: @merchant_id)

      @client.patch("shipments/1", { status: "delivered" })

      assert_requested :patch, %r{services/3pl/v1/shipments/1}i do |request|
        assert_equal({ "status" => "delivered" }, JSON.parse(request.body))
      end
    end

    def test_delete_request
      stub_tpl_request(:delete, merchant_id: @merchant_id)

      @client.delete("shipments/1")

      assert_requested :delete, %r{services/3pl/v1/shipments/1}i
    end

    # -- Error Handling Tests --

    def test_reraising_of_http_errors
      stub_tpl_request(:get, merchant_id: @merchant_id, status: 422, response: { error: "something went wrong" })

      error =
        assert_raises FulfilApi::Error do
          @client.get("shipments")
        end

      assert_equal 422, error.details[:response_status]
      assert_equal({ error: "something went wrong" }.to_json, error.details[:response_body])
    end

    # -- Integration via FulfilApi.tpl_client --

    def test_tpl_client_accessor
      FulfilApi.configure do |config|
        config.merchant_id = @merchant_id
        config.tpl = { auth_token: @auth_token }
      end

      client = FulfilApi.tpl_client

      assert_instance_of FulfilApi::TplClient, client
    end

    private

    def stub_tpl_request(method, merchant_id:, response: {}, status: 200)
      stub_request(method.to_sym, %r{#{merchant_id}\.fulfil\.io/services/3pl/v1}i)
        .and_return(status: status, body: response.to_json, headers: { "Content-Type": "application/json" })
    end
  end
end
