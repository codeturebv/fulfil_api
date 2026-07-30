# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class InstallableTest < ActiveSupport::TestCase
    def setup
      @shop = Shop.create!(name: "Other", fulfil_merchant_id: "other")
    end

    def token(**payload)
      FulfilApi::OAuth::Token.new(
        { "access_token" => "user-1234", "offline_access_token" => "bot-1234", "token_type" => "Bearer" }
          .merge(payload.transform_keys(&:to_s))
      )
    end

    test "fulfil_installed? is false without an installation" do
      assert_not @shop.fulfil_installed?
    end

    test "fulfil_installed? is false when the installation can no longer authenticate" do
      Installation.install(token(offline_access_token: nil, expires_in: 3600), merchant_id: "other", owner: @shop)
                  .update!(expires_at: 1.hour.ago)

      assert_not @shop.reload.fulfil_installed?
    end

    test "fulfil_installed? is true once the app is installed" do
      Installation.install token, merchant_id: "other", owner: @shop

      assert_predicate @shop.reload, :fulfil_installed?
    end

    test "with_fulfil_config authenticates the client as the record" do
      Installation.install token, merchant_id: "other", owner: @shop
      stub_fulfil_request(:get, model: "sale.sale")

      @shop.reload.with_fulfil_config { |client| client.get("model/sale.sale") }

      assert_requested :get, %r{other\.fulfil\.io/api/v2/model/sale\.sale},
                       headers: { "Authorization" => "Bearer bot-1234" }
    end

    test "with_fulfil_config refuses to run without an installation" do
      assert_raises FulfilApi::OAuth::Error do
        @shop.with_fulfil_config { |client| client }
      end
    end

    test "destroying the record takes its installations with it" do
      Installation.install token, merchant_id: "other", owner: @shop

      assert_difference -> { Installation.count }, -1 do
        @shop.destroy
      end
    end
  end
end
