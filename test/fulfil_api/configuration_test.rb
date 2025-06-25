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

    def test_global_configuration_applies_globally
      FulfilApi.configure do |config|
        config.access_token = "GLOBAL_TOKEN"
      end

      assert_equal "GLOBAL_TOKEN", FulfilApi.configuration.access_token

      token_from_thread = nil

      Thread.new do
        token_from_thread = FulfilApi.configuration.access_token
      end.join

      assert_equal "GLOBAL_TOKEN", token_from_thread
    end

    def test_with_config_temporarily_overrides_configuration
      FulfilApi.configure do |config|
        config.access_token = "GLOBAL_TOKEN"
      end

      FulfilApi.with_config(access_token: "TEMP_TOKEN") do
        assert_equal "TEMP_TOKEN", FulfilApi.configuration.access_token
      end

      assert_equal "GLOBAL_TOKEN", FulfilApi.configuration.access_token
    end
  end
end
