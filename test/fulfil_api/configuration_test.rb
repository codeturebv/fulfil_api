# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class ConfigurationTest < Minitest::Test
    def setup
      @config = FulfilApi::Configuration.new
    end

    def teardown
      # Ensure the configuration is always reset after completing each of the tests.
      FulfilApi.configuration = FulfilApi::Configuration.new
    end

    def test_default_configuration_values
      assert_equal Configuration::DEFAULT_API_VERSION, @config.api_version
      assert_nil @config.merchant_id
      assert_nil @config.tpl
      assert_equal Configuration::DEFAULT_REQUEST_OPTIONS, @config.request_options
    end

    def test_initialize_with_custom_options
      config = FulfilApi::Configuration.new(api_version: "v1", merchant_id: "codeture", request_options: { timeout: 1 })

      assert_equal "v1", config.api_version
      assert_equal "codeture", config.merchant_id
      assert_equal({ timeout: 1 }, config.request_options)
    end

    def test_configuration_update
      @config.api_version = "v1"
      @config.merchant_id = "codeture"

      assert_equal "v1", @config.api_version
      assert_equal "codeture", @config.merchant_id
    end

    def test_accessing_configuration_options
      config = FulfilApi::Configuration.new(api_version: nil, merchant_id: "codeture")

      assert_equal "v2", config.api_version
      assert_equal "codeture", config.merchant_id

      assert_raises NoMethodError do
        config.non_existing_configuration_option
      end
    end

    def test_configure_method
      FulfilApi.configure do |config|
        config.api_version = "3.0"
        config.merchant_id = "codeture"
      end

      assert_equal "3.0", FulfilApi.configuration.api_version
      assert_equal "codeture", FulfilApi.configuration.merchant_id
    end

    def test_configuration_assignment
      FulfilApi.configuration = { api_version: "v1", merchant_id: "codeture" }

      assert_equal "v1", FulfilApi.configuration.api_version
      assert_equal "codeture", FulfilApi.configuration.merchant_id
    end

    def test_with_config_temporary_configuration
      FulfilApi.with_config(api_version: "v1", merchant_id: "temporary") do
        assert_equal "v1", FulfilApi.configuration.api_version
        assert_equal "temporary", FulfilApi.configuration.merchant_id
      end

      assert_equal "v2", FulfilApi.configuration.api_version
    end

    def test_tpl_configuration
      FulfilApi.configure do |config|
        config.merchant_id = "codeture"
        config.tpl = { auth_token: "my-3pl-token", merchant_id: "tpl-merchant" }
      end

      assert_equal({ auth_token: "my-3pl-token", merchant_id: "tpl-merchant" }, FulfilApi.configuration.tpl)
    end

    def test_tpl_client_raises_error_when_auth_token_is_missing
      configuration = FulfilApi::Configuration.new(merchant_id: "codeture", tpl: {})

      assert_raises FulfilApi::TplClient::ConfigurationError do
        FulfilApi::TplClient.new(configuration)
      end
    end

    def test_tpl_client_raises_error_when_tpl_config_is_nil
      configuration = FulfilApi::Configuration.new(merchant_id: "codeture")

      assert_raises FulfilApi::TplClient::ConfigurationError do
        FulfilApi::TplClient.new(configuration)
      end
    end

    def test_tpl_client_raises_error_when_merchant_id_is_missing
      configuration = FulfilApi::Configuration.new(tpl: { auth_token: "my-3pl-token" })

      assert_raises FulfilApi::TplClient::ConfigurationError do
        FulfilApi::TplClient.new(configuration)
      end
    end

    def test_tpl_client_accessor
      FulfilApi.configure do |config|
        config.merchant_id = "codeture"
        config.tpl = { auth_token: "my-3pl-token" }
      end

      assert_instance_of FulfilApi::TplClient, FulfilApi.tpl_client
    end
  end
end
