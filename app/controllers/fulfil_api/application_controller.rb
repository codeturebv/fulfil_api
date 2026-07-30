# frozen_string_literal: true

module FulfilApi
  # Inherits from the host application's own base controller, so the engine's
  #   controllers pick up its layout, authentication, and multi-tenancy. Set
  #   `config.oauth.parent_controller` to change which controller that is.
  class ApplicationController < FulfilApi.configuration.oauth.parent_controller.constantize
    include FulfilApi::InstallationScoped
  end
end
