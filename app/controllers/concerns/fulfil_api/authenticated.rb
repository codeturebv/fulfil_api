# frozen_string_literal: true

module FulfilApi
  # Guarantees that every action of a controller runs with a working Fulfil API
  #   client, by sending the user through the OAuth flow when it does not.
  #
  # The user is returned to the action they were trying to reach once the app is
  #   installed, so a missing or expired token is a detour rather than a dead
  #   end.
  #
  # @example
  #   class SalesOrdersController < ApplicationController
  #     include FulfilApi::Authenticated
  #
  #     def index
  #       @sales_orders = FulfilApi::Resource.set(model_name: "sale.sale").limit(50)
  #     end
  #   end
  module Authenticated
    extend ActiveSupport::Concern
    include FulfilApi::InstallationScoped

    included do
      around_action :with_fulfil_installation
    end

    private

    # @return [void]
    def redirect_to_fulfil_installation
      redirect_to fulfil_api.new_installation_path(
        merchant_id: fulfil_merchant_id, return_to: request.fullpath
      )
    end

    # @return [void]
    def with_fulfil_installation(&)
      return redirect_to_fulfil_installation unless fulfil_installation&.usable?

      fulfil_installation.with_config(&)
    end
  end
end
