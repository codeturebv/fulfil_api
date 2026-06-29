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
      assert_equal Configuration::DEFAULT_CONNECTION_OPTIONS, @config.connection_options
    end

    def test_connection_options_merge_over_defaults
      config = FulfilApi::Configuration.new(connection_options: { idle_timeout: 2 })

      assert_equal 2, config.connection_options[:idle_timeout]
      assert_equal 1, config.connection_options[:max_retries]
    end

    def test_connection_options_allow_overriding_defaults
      config = FulfilApi::Configuration.new(connection_options: { max_retries: 0 })

      assert_equal 0, config.connection_options[:max_retries]
    end

    def test_connection_options_reset_to_defaults_when_assigned_nil
      config = FulfilApi::Configuration.new(connection_options: { pool_size: 5 })
      config.connection_options = nil

      assert_equal Configuration::DEFAULT_CONNECTION_OPTIONS, config.connection_options
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

    def test_with_config_inherits_unspecified_options_from_active_configuration
      FulfilApi.configure do |config|
        config.merchant_id = "codeture"
        config.access_token = FulfilApi::AccessToken.new("super-secret-token")
      end

      FulfilApi.with_config(request_options: { read_timeout: 60 }) do
        assert_equal "codeture", FulfilApi.configuration.merchant_id
        assert_equal "super-secret-token", FulfilApi.configuration.access_token.value
        assert_equal 60, FulfilApi.configuration.request_options[:read_timeout]
      end
    end

    def test_with_config_does_not_mutate_the_active_configuration
      FulfilApi.configure do |config|
        config.merchant_id = "codeture"
        config.request_options = { read_timeout: 5 }
      end

      FulfilApi.with_config(request_options: { read_timeout: 60 }) do
        # Temporary override is active inside the block.
      end

      assert_equal "codeture", FulfilApi.configuration.merchant_id
      assert_equal 5, FulfilApi.configuration.request_options[:read_timeout]
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
