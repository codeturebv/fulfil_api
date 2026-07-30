# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class InstallationTest < ActiveSupport::TestCase
    def token(**payload)
      FulfilApi::OAuth::Token.new(
        {
          "access_token" => "user-1234",
          "associated_user" => { "email" => "first.last@example.com", "id" => 7, "name" => "First Last" },
          "expires_in" => 3600,
          "offline_access_token" => "bot-1234",
          "scope" => ["sale.sale"],
          "token_type" => "Bearer"
        }.merge(payload.transform_keys(&:to_s))
      )
    end

    test "install records the granted token" do
      assert_difference -> { Installation.count }, +1 do
        Installation.install token, merchant_id: "acme"
      end

      installation = Installation.global.last

      assert_equal "acme", installation.merchant_id
      assert_equal "bot-1234", installation.offline_access_token
      assert_equal %w[sale.sale], installation.scopes
      assert_equal 7, installation.associated_user_id
    end

    test "install replaces the token of an earlier installation on the same workspace" do
      Installation.install token, merchant_id: "acme"

      assert_no_difference -> { Installation.count } do
        Installation.install token(access_token: "user-5678"), merchant_id: "acme"
      end

      assert_equal "user-5678", Installation.global.sole.access_token
    end

    test "install keeps a permanent token when re-authorizing without one" do
      Installation.install token, merchant_id: "acme"

      assert_no_changes -> { Installation.global.sole.offline_access_token }, from: "bot-1234" do
        Installation.install token(offline_access_token: nil), merchant_id: "acme"
      end
    end

    test "install scopes the installation to its owner" do
      shop = Shop.create!(name: "Acme")
      Installation.install token, merchant_id: "acme", owner: shop

      assert_empty Installation.global
      assert_equal shop, Installation.sole.owner
    end

    test "install normalizes the workspace of a Fulfil instance URL" do
      Installation.install token, merchant_id: "https://ACME.fulfil.io"

      assert_equal "acme", Installation.sole.merchant_id
    end

    test "an owner cannot be connected to a second workspace" do
      shop = Shop.create!(name: "Acme")
      Installation.install token, merchant_id: "acme", owner: shop
      second = Installation.new(merchant_id: "other", owner: shop, access_token: "user-1234")

      assert_not second.valid?
    end

    test "the application cannot be connected to a second workspace" do
      Installation.install token, merchant_id: "acme"
      second = Installation.new(merchant_id: "other", access_token: "user-1234")

      assert_not second.valid?
    end

    test "install moves an owner to another workspace instead of adding one" do
      Installation.install token, merchant_id: "acme"

      assert_no_difference -> { Installation.count } do
        Installation.install token, merchant_id: "other"
      end

      assert_equal "other", Installation.global.sole.merchant_id
    end

    test "install drops the permanent token granted by the workspace it moves away from" do
      Installation.install token, merchant_id: "acme"

      assert_changes -> { Installation.global.sole.offline_access_token }, from: "bot-1234", to: nil do
        Installation.install token(offline_access_token: nil), merchant_id: "other"
      end
    end

    test "installed_on finds the application wide installation" do
      installation = Installation.install token, merchant_id: "acme"

      assert_equal installation, Installation.installed_on(merchant_id: "acme")
    end

    test "installed_on ignores an installation belonging to another owner" do
      shop = Shop.create!(name: "Acme")
      Installation.install token, merchant_id: "acme", owner: shop

      assert_nil Installation.installed_on(merchant_id: "acme")
    end

    test "installed_on returns nothing without a workspace to look for" do
      Installation.install token, merchant_id: "acme"

      assert_nil Installation.installed_on(merchant_id: nil)
    end

    test "to_access_token prefers the permanent token" do
      installation = Installation.install token, merchant_id: "acme"

      assert_equal "bot-1234", installation.to_access_token.value
      assert_equal :oauth, installation.to_access_token.type
    end

    test "to_access_token falls back to the short lived token" do
      installation = Installation.install token(offline_access_token: nil), merchant_id: "acme"

      assert_equal "user-1234", installation.to_access_token.value
    end

    test "usable? is true for a permanent token that has outlived its session" do
      installation = Installation.install token, merchant_id: "acme"
      installation.update!(expires_at: 1.hour.ago)

      assert_predicate installation, :expired?
      assert_predicate installation, :usable?
    end

    test "usable? is false once a short lived token expired" do
      installation = Installation.install token(offline_access_token: nil), merchant_id: "acme"
      installation.update!(expires_at: 1.hour.ago)

      assert_not installation.usable?
    end

    test "with_config authenticates the Fulfil API client as the installation" do
      installation = Installation.install token, merchant_id: "acme"
      stub_fulfil_request(:get, model: "sale.sale")

      installation.with_config { |client| client.get("model/sale.sale") }

      assert_requested :get, %r{acme\.fulfil\.io/api/v2/model/sale\.sale},
                       headers: { "Authorization" => "Bearer bot-1234" }
    end

    test "with_config reverts the configuration afterwards" do
      installation = Installation.install token, merchant_id: "other"

      assert_no_changes -> { FulfilApi.configuration.merchant_id }, from: "acme" do
        installation.with_config { |client| client }
      end
    end
  end
end
