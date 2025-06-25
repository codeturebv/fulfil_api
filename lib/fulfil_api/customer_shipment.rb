# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::CustomerShipment} represents a single StockShipmentOut resource returned
  #   by the API endpoints of Fulfil.
  class CustomerShipment < Resource
    MODEL_NAME = "stock.shipment.out"

    class << self
      # Sets the fulfillment status of the customer shipment on hold
      #
      # @param id_or_ids [String, Integer, Array[String], Array[Integer]] The ID(s) of the customer shipment(s) to hold.
      # @param note [String] A note to define the reason for holding.
      # @return [Boolean] Returns true if hold successfully.
      # @raise [FulfilApi::Error] If an error occurs during holding the customer shipment.
      #
      # @example Hold a customer shipment
      #   FulfilApi::CustomerShipment.hold(123, note: "Double booking")
      #
      # @example Hold multipe customer shipments
      #   FulfilApi::CustomerShipment.hold([123, 456], note: "Double booking")
      def hold!(id_or_ids, note:) # rubocop:disable Naming/PredicateMethod
        FulfilApi.client.put("/model/#{MODEL_NAME}/hold", body: [[*id_or_ids].flatten, note])
        true
      end

      # Unholds the fulfillment status of the customer shipment
      #
      # @param id_or_ids [String, Integer, Array[String], Array[Integer]]
      #   The ID(s) of the customer shipment(s) to unhold.
      # @param note [String] A note to define the reason for unholding.
      # @return [Boolean] Returns true if hold successfully.
      # @raise [FulfilApi::Error] If an error occurs during holding the customer shipment.
      #
      # @example Unhold a customer shipment
      #   FulfilApi::CustomerShipment.unhold(123, note: "All clear")
      #
      # @example Unhold a customer shipment
      #   FulfilApi::CustomerShipment.unhold([123, 456], note: "All clear")
      def unhold!(id_or_ids, note:) # rubocop:disable Naming/PredicateMethod
        FulfilApi.client.put("/model/#{MODEL_NAME}/unhold", body: [[*id_or_ids].flatten, note])
        true
      end
    end

    # Sets the current customer shipment on hold, rescuing any errors that occur and handling them based on error type.
    #
    # @param note [String] A note to define the reason for holding.
    # @return [Boolean] Returns true if hold successfully, otherwise false.
    #
    # @example Holds a customer_shipment
    #   customer_shipment.hold("Holding the shipment for 30 minutes to allow edits to the order")
    def hold(note)
      self.class.hold!(id, note: note)
    rescue FulfilApi::Error => e
      handle_exception(e)
      false
    end

    # Unholds the current customer shipment, rescuing any errors that occur and handling them based on error type.
    #
    # @param note [String] A note to define the reason for unholding.
    # @return [Boolean] Returns true if unhold successfully, otherwise false.
    #
    # @example Unholds a customer_shipment
    #   customer_shipment.unhold("Ship out these items to the customer")
    def unhold(note)
      self.class.unhold!(id, note: note)
    rescue FulfilApi::Error => e
      handle_exception(e)
      false
    end
  end
end
