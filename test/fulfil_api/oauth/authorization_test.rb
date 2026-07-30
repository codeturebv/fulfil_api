# frozen_string_literal: true

require "test_helper"

module FulfilApi
  module OAuth
    class AuthorizationTest < Minitest::Test
      def setup
        @configuration = FulfilApi::Configuration.new(merchant_id: "acme")
        @configuration.oauth = {
          client_id: "client-id",
          client_secret: "client-secret",
          redirect_uri: "https://example.com/fulfil/callback",
          scopes: %w[sale.sale product.product]
        }
      end

      def authorization(**)
        Authorization.new(configuration: @configuration, **)
      end

      def test_generates_a_unique_state
        refute_equal Authorization.generate_state, Authorization.generate_state
      end

      def test_requires_the_credentials_of_the_oauth_app
        @configuration.oauth = nil

        assert_raises ConfigurationError do
          authorization
        end
      end

      def test_normalizes_the_merchant_id
        assert_equal "acme", authorization(merchant_id: "ACME.fulfil.io").merchant_id
        assert_equal "acme", authorization(merchant_id: " acme ").merchant_id
      end

      def test_falls_back_to_the_configured_merchant_id
        assert_equal "acme", authorization.merchant_id
      end

      def test_rejects_a_merchant_id_that_is_not_a_subdomain
        assert_raises MerchantIdInvalid do
          authorization(merchant_id: "evil.com/acme")
        end
      end

      def test_rejects_a_missing_merchant_id
        @configuration.merchant_id = nil

        assert_raises MerchantIdInvalid do
          authorization
        end
      end

      def test_points_the_consent_screen_url_at_the_merchants_workspace
        url = URI.parse(authorization.url(state: "nonce"))

        assert_equal "acme.fulfil.io", url.host
        assert_equal "/oauth/authorize", url.path
      end

      def test_asks_the_consent_screen_for_an_authorization_code
        parameters = url_parameters(authorization.url(state: "nonce"))

        assert_equal "code", parameters["response_type"]
        assert_equal "client-id", parameters["client_id"]
        assert_equal "https://example.com/fulfil/callback", parameters["redirect_uri"]
        assert_equal "nonce", parameters["state"]
      end

      def test_requests_offline_access_by_default
        assert_equal "offline_access", url_parameters(authorization.url(state: "nonce"))["access_type"]
      end

      def test_joins_the_scopes_the_way_fulfil_expects
        assert_equal "sale.sale,product.product", url_parameters(authorization.url(state: "nonce"))["scope"]
      end

      def test_omits_the_scope_when_no_scopes_are_requested
        @configuration.oauth.scopes = []

        refute_includes url_parameters(authorization.url(state: "nonce")).keys, "scope"
      end

      def test_prefers_an_explicit_redirect_uri
        url = authorization(redirect_uri: "https://other.example.com/callback").url(state: "nonce")

        assert_equal "https://other.example.com/callback", url_parameters(url)["redirect_uri"]
      end

      def test_exchanges_the_authorization_code_for_a_token
        stub_token_request(offline_access_token: "bot-1234")

        token = authorization.exchange("the-code")

        assert_equal "bot-1234", token.offline_access_token
        assert_requested :post, %r{acme\.fulfil\.io/oauth/token} do |request|
          request.body.include?("code=the-code")
        end
      end

      def test_identifies_the_client_with_basic_authentication
        stub_token_request

        authorization.exchange("the-code")

        credentials = Base64.strict_encode64("client-id:client-secret")

        assert_requested :post, %r{acme\.fulfil\.io/oauth/token},
                         headers: { "Authorization" => "Basic #{credentials}" }
      end

      def test_refuses_to_exchange_a_missing_authorization_code
        assert_raises TokenExchangeFailed do
          authorization.exchange(nil)
        end
      end

      def test_raises_when_fulfil_rejects_the_authorization_code
        stub_request(:post, %r{acme\.fulfil\.io/oauth/token})
          .to_return(status: 401, body: { error: "invalid_grant" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        assert_raises TokenExchangeFailed do
          authorization.exchange("the-code")
        end
      end

      private

      def url_parameters(url)
        URI.decode_www_form(URI.parse(url).query).to_h
      end

      def stub_token_request(**payload)
        stub_request(:post, %r{acme\.fulfil\.io/oauth/token})
          .to_return(
            status: 200,
            body: { access_token: "user-1234", expires_in: 3600, token_type: "Bearer" }.merge(payload).to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end
    end
  end
end
