# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module FulfilApi
  module Generators
    # Sets a Rails application up for Fulfil's OAuth flow: it writes an
    #   initializer, adds the migration for {FulfilApi::Installation}, and mounts
    #   {FulfilApi::Engine}.
    #
    # @example
    #   bin/rails generate fulfil_api:install
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Installs the Fulfil OAuth initializer, migration, and engine route."

      # @return [void]
      def copy_initializer
        template "fulfil_api.rb", "config/initializers/fulfil_api.rb"
      end

      # @return [void]
      def create_migration_file
        migration_template "create_fulfil_api_installations.rb",
                           "db/migrate/create_fulfil_api_installations.rb"
      end

      # @return [void]
      def mount_engine
        route %(mount FulfilApi::Engine => "#{FulfilApi::OAuth::Configuration::DEFAULT_MOUNT_PATH}")
      end

      # @return [void]
      def show_readme
        say <<~MESSAGE

          Fulfil's OAuth flow is installed. To finish setting it up:

            1. Run `bin/rails db:migrate` to create the fulfil_api_installations table.
            2. Run `bin/rails db:encryption:init` and store the keys in your credentials,
               unless Active Record encryption is already configured. The access tokens
               are encrypted at rest.
            3. Create an app on https://auth.fulfil.io/user/clients and whitelist
               #{FulfilApi::OAuth::Configuration::DEFAULT_MOUNT_PATH}/callback as a redirection URL.
            4. Fill in FULFIL_OAUTH_CLIENT_ID and FULFIL_OAUTH_CLIENT_SECRET.

        MESSAGE
      end

      private

      # @return [String] The Active Record migration version to generate against.
      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
