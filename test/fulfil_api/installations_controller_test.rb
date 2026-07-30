# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class InstallationsControllerTest < ActionDispatch::IntegrationTest
    def setup
      stub_token_request
    end

    def teardown
      FulfilApi.configuration.oauth.after_install_path = OAuth::Configuration::DEFAULT_AFTER_INSTALL_PATH
    end

    test "new sends the user to Fulfil's consent screen" do
      get "/fulfil/installation/new"

      assert_response :redirect

      location = URI.parse(response.headers["Location"])

      assert_equal "acme.fulfil.io", location.host
      assert_equal "/oauth/authorize", location.path
    end

    test "new asks Fulfil to redirect back to the engine's callback" do
      get "/fulfil/installation/new"

      parameters = URI.decode_www_form(URI.parse(response.headers["Location"]).query).to_h

      assert_equal "http://www.example.com/fulfil/callback", parameters["redirect_uri"]
    end

    test "new sends a nonce Fulfil has to hand back" do
      get "/fulfil/installation/new"

      parameters = URI.decode_www_form(URI.parse(response.headers["Location"]).query).to_h

      assert_equal session[InstallationsController::STATE_SESSION_KEY], parameters["state"]
    end

    test "new installs on the workspace given in the request" do
      get "/fulfil/installation/new", params: { merchant_id: "other" }

      assert_equal "other.fulfil.io", URI.parse(response.headers["Location"]).host
    end

    test "new refuses a workspace that is not a Fulfil subdomain" do
      assert_raises OAuth::MerchantIdInvalid do
        get "/fulfil/installation/new", params: { merchant_id: "evil.com" }
      end
    end

    test "the callback records the installation" do
      assert_difference -> { Installation.count }, +1 do
        install
      end

      installation = Installation.global.sole

      assert_equal "acme", installation.merchant_id
      assert_equal "bot-1234", installation.offline_access_token
    end

    test "the callback returns the user to where they came from" do
      install(return_to: "/sales_orders")

      assert_redirected_to "/sales_orders"
    end

    test "the callback ignores a return path pointing at another host" do
      install(return_to: "//evil.example.com")

      assert_redirected_to OAuth::Configuration::DEFAULT_AFTER_INSTALL_PATH
    end

    test "the callback honours a configured landing path" do
      FulfilApi.configuration.oauth.after_install_path = ->(installation) { "/workspaces/#{installation.merchant_id}" }

      install

      assert_redirected_to "/workspaces/acme"
    end

    test "the callback rejects a nonce that does not match the authorization request" do
      get "/fulfil/installation/new"

      assert_raises OAuth::StateMismatch do
        get "/fulfil/callback", params: { code: "the-code", state: "a-different-nonce" }
      end
    end

    test "the callback rejects a request that did not start an authorization" do
      assert_raises OAuth::StateMismatch do
        get "/fulfil/callback", params: { code: "the-code", state: "a-nonce" }
      end
    end

    test "the callback reports an installation the user cancelled" do
      get "/fulfil/installation/new"

      assert_raises OAuth::AuthorizationDenied do
        get "/fulfil/callback", params: { error: "access_denied", state: session[InstallationsController::STATE_SESSION_KEY] }
      end
    end

    test "the callback does not record an installation the user cancelled" do
      get "/fulfil/installation/new"

      assert_no_difference -> { Installation.count } do
        assert_raises OAuth::AuthorizationDenied do
          get "/fulfil/callback", params: { error: "access_denied", state: session[InstallationsController::STATE_SESSION_KEY] }
        end
      end
    end

    private

    def install(**options)
      get "/fulfil/installation/new", params: options.slice(:merchant_id, :return_to)
      get "/fulfil/callback", params: { code: "the-code", state: session[InstallationsController::STATE_SESSION_KEY] }
    end

    def stub_token_request
      stub_request(:post, %r{fulfil\.io/oauth/token})
        .to_return(
          status: 200,
          body: {
            access_token: "user-1234", expires_in: 3600, offline_access_token: "bot-1234",
            scope: ["sale.sale"], token_type: "Bearer"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end
end
