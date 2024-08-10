# frozen_string_literal: true

require "test_helper"

class FulfilConfigurationTest < Minitest::Test
  def setup
    @config = Fulfil::Configuration.new
  end

  def teardown
    # Ensure the configuration is always reset after completing each of the tests.
    Fulfil.configuration = Fulfil::Configuration.new
  end

  def test_default_configuration_values
    assert_equal "2.0", @config.api_version
    assert_nil @config.merchant_id
  end

  def test_initialize_with_custom_options
    config = Fulfil::Configuration.new(api_version: "1.0", merchant_id: "codeture")

    assert_equal "1.0", config.api_version
    assert_equal "codeture", config.merchant_id
  end

  def test_configuration_update
    @config.api_version = "1.0"
    @config.merchant_id = "codeture"

    assert_equal "1.0", @config.api_version
    assert_equal "codeture", @config.merchant_id
  end

  def test_accessing_configuration_options
    config = Fulfil::Configuration.new(api_version: nil, merchant_id: "codeture")

    assert_equal "2.0", config.api_version
    assert_equal "codeture", config.merchant_id

    assert_raises NoMethodError do
      config.non_existing_configuration_option
    end
  end

  def test_configure_method
    Fulfil.configure do |config|
      config.api_version = "3.0"
      config.merchant_id = "codeture"
    end

    assert_equal "3.0", Fulfil.configuration.api_version
    assert_equal "codeture", Fulfil.configuration.merchant_id
  end

  def test_configuration_assignment
    Fulfil.configuration = { api_version: "1.0", merchant_id: "codeture" }

    assert_equal "1.0", Fulfil.configuration.api_version
    assert_equal "codeture", Fulfil.configuration.merchant_id
  end

  def test_with_config_temporary_configuration
    Fulfil.with_config(api_version: "1.0", merchant_id: "temporary") do
      assert_equal "1.0", Fulfil.configuration.api_version
      assert_equal "temporary", Fulfil.configuration.merchant_id
    end

    # Ensure the original configuration is restored after the block
    assert_equal "2.0", Fulfil.configuration.api_version
  end
end
