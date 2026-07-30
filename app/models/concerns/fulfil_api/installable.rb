# frozen_string_literal: true

module FulfilApi
  # Gives a record its own Fulfil installation, so an application that serves
  #   many merchants can keep one access token per tenant instead of one for the
  #   whole application. A record is connected to a single Fulfil workspace:
  #   installing on another one replaces what came before.
  #
  # @example
  #   class Shop < ApplicationRecord
  #     include FulfilApi::Installable
  #   end
  #
  #   shop.with_fulfil_config do |client|
  #     client.get("model/sale.sale")
  #   end
  #
  # The concern deliberately leaves the Fulfil workspace of a record alone: that
  #   is usually a column on the record itself, which the authorization flow
  #   reads through `fulfil_merchant_id` in the host's ApplicationController.
  module Installable
    extend ActiveSupport::Concern

    included do
      has_one :fulfil_installation, as: :owner, class_name: "FulfilApi::Installation", dependent: :destroy
    end

    # @return [true, false] Whether the record can talk to the Fulfil API.
    def fulfil_installed?
      fulfil_installation&.usable? || false
    end

    # Runs a block against the Fulfil API as this record.
    #
    # @yieldparam [FulfilApi::Client] client A client authenticated as this record.
    # @raise [FulfilApi::OAuth::Error] When the record has no usable installation.
    # @return [void]
    def with_fulfil_config(&)
      unless fulfil_installed?
        raise FulfilApi::OAuth::Error,
              "#{self.class.name} #{id} has no usable Fulfil installation"
      end

      fulfil_installation.with_config(&)
    end
  end
end
