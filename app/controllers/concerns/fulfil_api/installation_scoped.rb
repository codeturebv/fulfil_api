# frozen_string_literal: true

module FulfilApi
  # Answers which Fulfil installation a request belongs to.
  #
  # Out of the box that is the application-wide installation on the configured
  #   merchant, which is what a Rails application built for a single merchant
  #   needs. An application serving many merchants overrides these methods in
  #   its own `ApplicationController` to scope the installation to the current
  #   tenant.
  #
  # The engine's own controllers include this module below the application's
  #   parent controller. The defaults therefore defer to an override further up
  #   the chain, or the OAuth callback would ignore the tenant and record an
  #   application-wide installation.
  #
  # @example An application with an installation per shop
  #   class ApplicationController < ActionController::Base
  #     private
  #
  #     def fulfil_installation_owner
  #       Current.shop
  #     end
  #
  #     def fulfil_merchant_id
  #       Current.shop.fulfil_merchant_id
  #     end
  #   end
  module InstallationScoped
    extend ActiveSupport::Concern

    private

    # @return [FulfilApi::Installation, nil]
    def fulfil_installation
      return @fulfil_installation if defined?(@fulfil_installation)

      @fulfil_installation = FulfilApi::Installation.installed_on(
        merchant_id: fulfil_merchant_id, owner: fulfil_installation_owner
      )
    end

    # The record the installation belongs to. `nil` means the installation is
    #   shared by the whole application.
    #
    # @return [ActiveRecord::Base, nil]
    def fulfil_installation_owner
      defined?(super) ? super : nil
    end

    # @return [String, nil] The Fulfil workspace of the current request.
    def fulfil_merchant_id
      defined?(super) ? super : FulfilApi.configuration.merchant_id
    end
  end
end
