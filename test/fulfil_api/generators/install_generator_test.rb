# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/fulfil_api/install/install_generator"

module FulfilApi
  module Generators
    class InstallGeneratorTest < Rails::Generators::TestCase
      tests InstallGenerator
      destination File.expand_path("../../../tmp/generator", __dir__)

      def setup
        prepare_destination
        FileUtils.mkdir_p("#{destination_root}/config")
        File.write("#{destination_root}/config/routes.rb", "Rails.application.routes.draw do\nend\n")
      end

      test "writes an initializer holding the OAuth app's credentials" do
        run_generator

        assert_file "config/initializers/fulfil_api.rb", /config\.oauth\.client_id/, /config\.oauth\.client_secret/
      end

      test "adds the migration for the installations table" do
        run_generator

        assert_migration "db/migrate/create_fulfil_api_installations.rb" do |migration|
          assert_match(/create_table :fulfil_api_installations/, migration)
          assert_match(/ActiveRecord::Migration\[\d+\.\d+\]/, migration)
        end
      end

      test "mounts the engine" do
        run_generator

        assert_file "config/routes.rb", %r{mount FulfilApi::Engine => "/fulfil"}
      end
    end
  end
end
