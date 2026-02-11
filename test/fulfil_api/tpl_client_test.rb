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

      stub_fulfil_tpl_request(:get, path: "inbound-transfers")
      client.get("inbound-transfers")

      assert_requested :get, "https://#{tpl_merchant_id}.fulfil.io/services/3pl/v1/inbound-transfers"
    end

    def test_falls_back_to_global_merchant_id
      stub_fulfil_tpl_request(:get, path: "inbound-transfers")

      @client.get("inbound-transfers")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/inbound-transfers"
    end

    def test_defaults_to_v1_api_version
      stub_fulfil_tpl_request(:get, path: "inbound-transfers")

      @client.get("inbound-transfers")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/inbound-transfers"
    end

    def test_uses_custom_api_version_when_provided
      configuration = FulfilApi::Configuration.new(
        merchant_id: @merchant_id,
        tpl: { auth_token: @auth_token, api_version: "v2" }
      )

      client = FulfilApi::TplClient.new(configuration)

      stub_fulfil_tpl_request(:get, path: "inbound-transfers")
      client.get("inbound-transfers")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v2/inbound-transfers"
    end

    def test_builds_correct_request_path
      stub_fulfil_tpl_request(:get, path: "inbound-transfers/receive.json")

      @client.get("inbound-transfers/receive.json")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/inbound-transfers/receive.json"
    end

    def test_squeezes_duplicate_slashes_in_path
      stub_fulfil_tpl_request(:get, path: "inbound-transfers")

      @client.get("/inbound-transfers")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/inbound-transfers"
    end

    def test_includes_bearer_token_in_requests
      stub_fulfil_tpl_request(:get, path: "inbound-transfers")

      @client.get("inbound-transfers")

      assert_requested :get, "https://#{@merchant_id}.fulfil.io/services/3pl/v1/inbound-transfers" do |request|
        assert_equal "Bearer #{@auth_token}", request.headers["Authorization"]
      end
    end

    def test_get_request
      stub_fulfil_tpl_request(:get, path: "inbound-transfers", response: [{ "id" => 1 }])

      result = @client.get("inbound-transfers")

      assert_equal [{ "id" => 1 }], result
    end

    def test_get_request_with_url_parameters
      stub_fulfil_tpl_request(:get, path: "inbound-transfers")

      @client.get("inbound-transfers", page: 1, per_page: 25)

      assert_requested :get, %r{services/3pl/v1/inbound-transfers\?page=1&per_page=25}i
    end

    def test_post_request
      stub_fulfil_tpl_request(:post, path: "inbound-transfers/receive.json")

      @client.post("inbound-transfers/receive.json", { tracking_number: "ABC123" })

      assert_requested :post, %r{services/3pl/v1/inbound-transfers/receive\.json}i do |request|
        assert_equal({ "tracking_number" => "ABC123" }, JSON.parse(request.body))
      end
    end

    def test_put_request
      stub_fulfil_tpl_request(:put, path: "inbound-transfers/receive.json")

      @client.put("inbound-transfers/receive.json", { status: "received" })

      assert_requested :put, %r{services/3pl/v1/inbound-transfers/receive\.json}i do |request|
        assert_equal({ "status" => "received" }, JSON.parse(request.body))
      end
    end

    def test_put_request_without_body
      stub_fulfil_tpl_request(:put, path: "inbound-transfers/receive.json")

      @client.put("inbound-transfers/receive.json")

      assert_requested :put, %r{services/3pl/v1/inbound-transfers/receive\.json}i, times: 1 do |request|
        assert_empty request.body
      end
    end

    def test_patch_request
      stub_fulfil_tpl_request(:patch, path: "inbound-transfers/receive.json")

      @client.patch("inbound-transfers/receive.json", { status: "received" })

      assert_requested :patch, %r{services/3pl/v1/inbound-transfers/receive\.json}i do |request|
        assert_equal({ "status" => "received" }, JSON.parse(request.body))
      end
    end

    def test_reraising_of_http_errors
      stub_fulfil_tpl_request(:get, path: "inbound-transfers", status: 422, response: { error: "something went wrong" })

      error =
        assert_raises FulfilApi::Error do
          @client.get("inbound-transfers")
        end

      assert_equal 422, error.details[:response_status]
      assert_equal({ error: "something went wrong" }.to_json, error.details[:response_body])
    end
  end
end
