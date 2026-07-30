# frozen_string_literal: true

require "test_helper"

module FulfilApi
  module OAuth
    class ConfigurationTest < Minitest::Test
      def test_default_configuration_values
        config = Configuration.new

        assert_equal Configuration::DEFAULT_ACCESS_TYPE, config.access_type
        assert_equal Configuration::DEFAULT_AFTER_INSTALL_PATH, config.after_install_path
        assert_equal Configuration::DEFAULT_PARENT_CONTROLLER, config.parent_controller
        assert_empty config.scopes
        assert_nil config.client_id
      end

      def test_configured_requires_a_client_id_and_secret
        refute_predicate Configuration.new(client_id: "id"), :configured?
        refute_predicate Configuration.new(client_secret: "secret"), :configured?
        assert_predicate Configuration.new(client_id: "id", client_secret: "secret"), :configured?
      end

      def test_access_type_accepts_the_supported_types
        assert_equal :user_session, Configuration.new(access_type: "user_session").access_type
        assert_equal :offline_access, Configuration.new(access_type: :offline_access).access_type
      end

      def test_access_type_rejects_unsupported_types
        assert_raises ArgumentError do
          Configuration.new(access_type: :implicit)
        end
      end

      def test_offline_access_reflects_the_access_type
        assert_predicate Configuration.new(access_type: :offline_access), :offline_access?
        refute_predicate Configuration.new(access_type: :user_session), :offline_access?
      end

      def test_scopes_accept_a_comma_separated_string
        config = Configuration.new(scopes: "sale.sale, product.product")

        assert_equal %w[sale.sale product.product], config.scopes
      end

      def test_scopes_are_deduplicated_and_stripped
        config = Configuration.new(scopes: ["sale.sale", " sale.sale ", "", "product.product"])

        assert_equal %w[sale.sale product.product], config.scopes
      end
    end
  end
end
