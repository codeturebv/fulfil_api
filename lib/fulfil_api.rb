# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("oauth" => "OAuth")
loader.ignore("#{__dir__}/fulfil_api/engine.rb")
loader.ignore("#{__dir__}/fulfil_api/test_helper.rb")
loader.ignore("#{__dir__}/generators")
loader.setup

require "active_support"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"

module FulfilApi
end

loader.eager_load

# The Rails-specific parts of the gem — the engine, its models, its controllers,
#   and its generators — are only loaded when the gem is used from within a
#   Rails application.
require "fulfil_api/engine" if defined?(Rails::Engine)
