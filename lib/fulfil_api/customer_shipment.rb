# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::CustomerShipment} represents a single StockShipmentOut resource returned
  #   by the API endpoints of Fulfil.
  class CustomerShipment < Resource
    MODEL_NAME = "stock.shipment.out"

    class << self
      # Sets the fulfillment status of the customer shipment on hold
      #
      # @param id [String, Integer, Array[String], Array[Integer]] The ID of the customer shipment to set on hold.
      # @param note [String] A note to define th reason for holding. (Optional)
      # @param hold_reason [String] An hold reason ID. (Optional)
      # @return [FulfilApi::Resource] The on hold customer shipment
      #
      # @example Hold a customer shipment
      #   FulfilApi::CustomerShipment.hold(id: 123, note: "Double booking", hold_reason: hold_reason_id)
      def hold(id:, note: nil, hold_reason: nil)
        customer_shipment = new(id: [*id].flatten, model_name: MODEL_NAME)
        customer_shipment.hold(note: note, hold_reason: hold_reason)
      end

      # Unholds the fulfillment status of the customer shipment
      #
      # @param id [String, Integer, Array[String], Array[Integer]] The ID of the customer shipment to set unhold.
      # @param note [String] A note to define the reason for unholding.
      # @return [FulfilApi::Resource] The unhold customer shipment
      #
      # @example Unhold a customer shipment
      #   FulfilApi::CustomerShipment.unhold(id: 123, note: "All clear")
      def unhold(id:, note: nil)
        customer_shipment = new(id: [*id].flatten, model_name: MODEL_NAME)
        customer_shipment.unhold(note)
      end
    end

    # Sets the current customer shipment on hold, rescuing any errors that occur and handling them based on error type.
    #
    # @param attributes [Hash] The attributes to assign to the customer_shipment.
    # @return [Booleans] Returns true if hold successfully, otherwise false.
    # @raise [FulfilApi::Error] If an error occurs during holding the customer shipment.
    #
    # @example Holds a customer_shipment
    #   customer_shipment.hold({note: "Double booking"})
    def hold(note: nil, hold_reason: nil)
      if id.present?
        if id.present?
          FulfilApi.client.put("/model/#{MODEL_NAME}/hold",
                               body: [[id], { note: note, hold_reason: hold_reason }.compact_blank])
        end
        return true
      end

      false
    rescue FulfilApi::Error => e
      handle_error(e)
    end

    # Unholds the current customer shipment, rescuing any errors that occur and handling them based on error type.
    #
    # @param note [String] A note to define the reason for unholding.
    # @return [Boolean] Returns true if unhold successfully, otherwise false.
    # @raise [FulfilApi::Error] If an error occurs during unholding the customer shipment.
    #
    # @example Unholds a customer_shipment
    #   customer_shipment.unhold(note: "Double booking")
    def unhold(note: nil)
      if id.present?
        FulfilApi.client.put("/model/#{MODEL_NAME}/unhold", body: [[id], { note: note }.compact_blank])
        return true
      end

      false
    rescue FulfilApi::Error => e
      handle_error(e)
    end

    private

    def handle_error(err)
      case (error = JSON.parse(err.details[:response_body]).deep_symbolize_keys!)
      in { type: "UserError" }
        errors.add(code: error[:code], type: :user, message: error[:message])
      in { code: Integer, name: String, description: String }
        errors.add(code: error[:code], type: :authorization, message: error[:description])
      else
        errors.add(code: error[:code], type: :system, message: err.message)
      end

      false
    end
  end
end
