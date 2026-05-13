# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class ClientTest < Minitest::Test
    def setup
      @merchant_id = "merchant-#{SecureRandom.uuid}"

      @client = FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: @merchant_id))
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

    def test_inclusion_of_oauth_access_token
      oauth_access_token = FulfilApi::AccessToken.new(SecureRandom.uuid, type: :oauth)

      client = FulfilApi::Client.new(
        FulfilApi::Configuration.new(merchant_id: @merchant_id, access_token: oauth_access_token)
      )

      stub_fulfil_request(:get)
      client.get("sale.sale/123")

      assert_requested :get, %r{sale\.sale/123}i do |request|
        assert_equal "Bearer #{oauth_access_token.value}", request.headers["Authorization"]
      end
    end

    def test_inclusion_of_personal_access_token
      personal_access_token = FulfilApi::AccessToken.new(SecureRandom.uuid)

      client = FulfilApi::Client.new(
        FulfilApi::Configuration.new(merchant_id: @merchant_id, access_token: personal_access_token)
      )

      stub_fulfil_request(:get)
      client.get("sale.sale/123")

      assert_requested :get, %r{sale\.sale/123}i do |request|
        assert_equal personal_access_token.value, request.headers["X-Api-Key"]
      end
    end

    def test_exclusion_of_any_access_token_when_not_configured
      client = FulfilApi::Client.new(
        FulfilApi::Configuration.new(merchant_id: @merchant_id, access_token: nil)
      )

      stub_fulfil_request(:get)
      client.get("sale.sale/123")

      assert_requested :get, %r{sale\.sale/123}i do |request|
        refute_includes request.headers.keys, "X-API-KEY"
        refute_includes request.headers.keys, "Authorization"
      end
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

    def test_reuses_connection_across_client_instances_with_same_configuration
      FulfilApi::Client.reset_connection_cache!

      configuration = FulfilApi::Configuration.new(merchant_id: @merchant_id)

      first_client = FulfilApi::Client.new(configuration)
      second_client = FulfilApi::Client.new(configuration)

      assert_same first_client.send(:connection), second_client.send(:connection)
    end

    def test_builds_separate_connections_for_different_merchants
      FulfilApi::Client.reset_connection_cache!

      first_client = FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: "merchant-a"))
      second_client = FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: "merchant-b"))

      refute_same first_client.send(:connection), second_client.send(:connection)
    end

    def test_shares_connection_across_clients_with_different_access_tokens_for_same_merchant
      FulfilApi::Client.reset_connection_cache!

      first_client = FulfilApi::Client.new(
        FulfilApi::Configuration.new(
          merchant_id: @merchant_id,
          access_token: FulfilApi::AccessToken.new("token-a")
        )
      )
      second_client = FulfilApi::Client.new(
        FulfilApi::Configuration.new(
          merchant_id: @merchant_id,
          access_token: FulfilApi::AccessToken.new("token-b")
        )
      )

      assert_same first_client.send(:connection), second_client.send(:connection)
    end

    def test_excludes_credentials_from_connection_cache_key
      FulfilApi::Client.reset_connection_cache!

      configuration = FulfilApi::Configuration.new(
        merchant_id: @merchant_id,
        access_token: FulfilApi::AccessToken.new("super-secret-token")
      )
      client = FulfilApi::Client.new(configuration)

      refute_includes client.send(:connection_cache_key), "super-secret-token"
    end

    def test_applies_access_token_per_request_when_connection_is_shared
      FulfilApi::Client.reset_connection_cache!

      first_token = FulfilApi::AccessToken.new(SecureRandom.uuid)
      second_token = FulfilApi::AccessToken.new(SecureRandom.uuid)

      stub_fulfil_request(:get)

      build_client(first_token).get("sale.sale/123")
      build_client(second_token).get("sale.sale/123")

      assert_requested :get, %r{sale\.sale/123}i, headers: { "X-Api-Key" => first_token.value }, times: 1
      assert_requested :get, %r{sale\.sale/123}i, headers: { "X-Api-Key" => second_token.value }, times: 1
    end

    private

    def build_client(access_token)
      FulfilApi::Client.new(
        FulfilApi::Configuration.new(merchant_id: @merchant_id, access_token: access_token)
      )
    end
  end
end
