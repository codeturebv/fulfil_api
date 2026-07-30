# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] = "test"

# Boots a minimal Rails application, so the engine, its model, and its
#   controllers are exercised the way a host application would use them. It
#   requires the gem itself along the way.
require_relative "dummy/config/environment"

require "fulfil_api/test_helper"

require "minitest/autorun"
require "rails/test_help"

# Loaded after `rails/test_help`, which hands out a fresh connection to the
#   in-memory database the schema has to end up in.
ActiveRecord::Migration.verbose = false
require_relative "dummy/db/schema"

# Load all support files for the unit tests
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |file| require file }
