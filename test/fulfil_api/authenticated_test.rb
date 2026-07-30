# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class AuthenticatedTest < ActionDispatch::IntegrationTest
    def token(**payload)
      FulfilApi::OAuth::Token.new(
        { "access_token" => "user-1234", "offline_access_token" => "bot-1234", "token_type" => "Bearer" }
          .merge(payload.transform_keys(&:to_s))
      )
    end

    test "sends a user without an installation through the OAuth flow" do
      get "/sales_orders"

      assert_redirected_to "/fulfil/installation/new?merchant_id=acme&return_to=%2Fsales_orders"
    end

    test "sends a user whose token expired through the OAuth flow" do
      Installation.install(token(offline_access_token: nil), merchant_id: "acme").update!(expires_at: 1.hour.ago)

      get "/sales_orders"

      assert_response :redirect
    end

    test "authenticates the request as the application wide installation" do
      Installation.install token, merchant_id: "acme"

      get "/sales_orders"

      assert_response :success
      assert_equal "bot-1234", response.body
    end

    test "reverts the configuration after the request" do
      Installation.install token, merchant_id: "acme"

      assert_no_changes -> { FulfilApi.configuration.access_token } do
        get "/sales_orders"
      end
    end

    test "authenticates the request as the installation of the current tenant" do
      shop = Shop.create!(name: "Other", fulfil_merchant_id: "other")
      Installation.install token, merchant_id: "other", owner: shop

      get "/shop_sales_orders", params: { shop_id: shop.id }

      assert_response :success
      assert_equal "other", response.body
    end

    test "ignores an installation belonging to another tenant" do
      shop = Shop.create!(name: "Other", fulfil_merchant_id: "other")
      Installation.install token, merchant_id: "other"

      get "/shop_sales_orders", params: { shop_id: shop.id }

      assert_redirected_to "/fulfil/installation/new?merchant_id=other" \
                           "&return_to=%2Fshop_sales_orders%3Fshop_id%3D#{shop.id}"
    end
  end
end
