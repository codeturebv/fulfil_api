# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
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
