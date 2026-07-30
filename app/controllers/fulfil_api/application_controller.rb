# frozen_string_literal: true

module FulfilApi
  # Inherits from the controller named by `config.oauth.parent_controller`, so
  #   the engine's controllers pick up the host application's authentication,
  #   layout, and multi-tenancy.
  #
  # Until an application names one, the flow refuses to run rather than falling
  #   back to something that looks reasonable. An unauthenticated OAuth flow lets
  #   a stranger walk through it and record their own Fulfil workspace over the
  #   application's, and a flow that runs outside the application's tenancy
  #   silently records an installation against the wrong owner.
  class ApplicationController < FulfilApi.configuration.oauth.parent_controller_class
    include FulfilApi::InstallationScoped

    before_action :verify_parent_controller!

    private

    # @raise [FulfilApi::OAuth::ConfigurationError]
    # @return [void]
    def verify_parent_controller!
      return if FulfilApi.configuration.oauth.parent_controller_configured?

      raise FulfilApi::OAuth::ConfigurationError,
            "Set config.oauth.parent_controller to the controller that authenticates a request in this " \
            "application before using the OAuth flow. Without one, anyone can reach the flow and record " \
            "their own Fulfil workspace over yours."
    end
  end
end
