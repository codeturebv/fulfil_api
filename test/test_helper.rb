# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fulfil_api"
require "fulfil_api/test_helper"

require "minitest/autorun"

# Load all support files for the unit tests
Dir["test/support/**/*.rb"].each { |f| require f }
