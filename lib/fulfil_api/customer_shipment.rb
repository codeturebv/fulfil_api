# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::CustomerShipment} represents a single StockShipmentOut resource returned
  #   by the API endpoints of Fulfil.
  class CustomerShipment < Resource
    MODEL_NAME = "stock.shipment.out"

    class << self
      # Sets the fulfillment status of the customer shipment on hold
      #
      # @param id_or_ids [String, Integer, Array[String], Array[Integer]] The ID of the customer shipment to set on hold
      # @param note [String] A note to define th reason for holding. (Optional)
      # @param hold_reason [String] An hold reason ID. (Optional)
      # @return [Boolean] Returns true if hold successfully, otherwise instance with errors.
      # @raise [FulfilApi::Error] If an error occurs during holding the customer shipment.
      #
      # @example Hold a customer shipment
      #   FulfilApi::CustomerShipment.hold(123, note: "Double booking", hold_reason: hold_reason_id)
      # @example Hold multipe customer shipments
      #   FulfilApi::CustomerShipment.hold([123, 456], note: "Double booking", hold_reason: hold_reason_id)
      def hold(id_or_ids, note: nil, hold_reason: nil)
        if id_or_ids.present?
          FulfilApi.client.put("/model/#{MODEL_NAME}/hold",
                               body: [[id_or_ids], { note: note, hold_reason: hold_reason }.compact_blank])
        end

        true
      rescue FulfilApi::Error => e
        error = JSON.parse(e.details[:response_body]).deep_symbolize_keys!

        customer_shipment = new(id: id_or_ids, model_name: MODEL_NAME)
        customer_shipment.errors.add(code: error[:code], type: :system, message: e.message)

        customer_shipment
      end

      # Unholds the fulfillment status of the customer shipment
      #
      # @param id_or_ids [String, Integer, Array[String], Array[Integer]] The ID of the customer shipment to set unhold.
      # @param note [String] A note to define the reason for unholding.
      # @return [Boolean] Returns true if hold successfully, otherwise instance with errors.
      # @raise [FulfilApi::Error] If an error occurs during holding the customer shipment.
      #
      # @example Unhold a customer shipment
      #   FulfilApi::CustomerShipment.unhold(123, note: "All clear")
      # @example Unhold a customer shipment
      #   FulfilApi::CustomerShipment.unhold([123, 456], note: "All clear")
      def unhold(id_or_ids, note: nil)
        if id_or_ids.present?
          FulfilApi.client.put("/model/#{MODEL_NAME}/unhold", body: [[id_or_ids], { note: note }.compact_blank])
        end

        true
      rescue FulfilApi::Error => e
        error = JSON.parse(e.details[:response_body]).deep_symbolize_keys!

        customer_shipment = new(id: id_or_ids, model_name: MODEL_NAME)
        customer_shipment.errors.add(code: error[:code], type: :system, message: e.message)

        customer_shipment
      end

      def self.handle_error(err)
        case (error = JSON.parse(err.details[:response_body]).deep_symbolize_keys!)
        in { type: "UserError" }
          errors.add(code: error[:code], type: :user, message: error[:message])
        in { code: Integer, name: String, description: String }
          errors.add(code: error[:code], type: :authorization, message: error[:description])
        else
        end
      end
    end

    # Sets the current customer shipment on hold, rescuing any errors that occur and handling them based on error type.
    #
    # @param attributes [Hash] The attributes to assign to the customer_shipment.
    # @return [Boolean] Returns true if hold successfully, otherwise instance with errors.
    #
    # @example Holds a customer_shipment
    #   customer_shipment.hold(note: "Double booking", hold_reason: hold_reason_id)
    def hold(note: nil, hold_reason: nil)
      self.class.hold(id, note: note, hold_reason: hold_reason)
    end

    # Unholds the current customer shipment, rescuing any errors that occur and handling them based on error type.
    #
    # @param note [String] A note to define the reason for unholding.
    # @return [Boolean] Returns true if unhold successfully, otherwise instance with errors.
    #
    # @example Unholds a customer_shipment
    #   customer_shipment.unhold(note: "Double booking")
    def unhold(note: nil)
      self.class.unhold(id, note: note)
    end
  end
end
