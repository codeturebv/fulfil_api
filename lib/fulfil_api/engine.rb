# frozen_string_literal: true

require "rails/engine"

module FulfilApi
  # Ships the OAuth flow as a mountable engine, so a Rails application only has
  #   to mount it and point Fulfil's whitelisted redirect URL at its callback.
  #
  # @example config/routes.rb
  #   mount FulfilApi::Engine => "/fulfil"
  class Engine < ::Rails::Engine
    isolate_namespace FulfilApi
  end
end
