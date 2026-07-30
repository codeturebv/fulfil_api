# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_record/railtie"

require "fulfil_api"

module Dummy
  # A minimal Rails application to exercise the engine, its model, and its
  #   controllers against.
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(IO::NULL)
    config.secret_key_base = "fulfil-api-dummy-application-secret-key-base"

    config.active_record.encryption.deterministic_key = "fulfil-api-dummy-deterministic-key"
    config.active_record.encryption.key_derivation_salt = "fulfil-api-dummy-key-derivation-salt"
    config.active_record.encryption.primary_key = "fulfil-api-dummy-primary-key"

    config.action_dispatch.show_exceptions = :none
    config.consider_all_requests_local = true

    # The dummy application has no migrations to check the test schema against.
    config.active_record.maintain_test_schema = false
  end
end

FulfilApi.configure do |config|
  config.merchant_id = "acme"

  config.oauth.client_id = "client-id"
  config.oauth.client_secret = "client-secret"
  config.oauth.scopes = %w[sale.sale]
end

# The configuration every test starts from. Tests that replace the active
#   configuration would otherwise leave the next test without credentials.
FULFIL_API_BOOT_CONFIGURATION = FulfilApi.configuration

Dummy::Application.initialize!
