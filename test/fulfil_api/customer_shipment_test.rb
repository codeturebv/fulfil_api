# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class CustomerShipmentTest < Minitest::Test
    def setup
      @customer_shipment = CustomerShipment.new(id: 123, model_name: CustomerShipment::MODEL_NAME)
    end

    def test_holding_shipment_successfully
      stub_fulfil_request(:put, response: nil)

      assert @customer_shipment.hold
    end

    def test_unholding_shipment_successfully
      stub_fulfil_request(:put, response: nil)

      assert @customer_shipment.unhold
    end

    def test_holding_makes_no_request_when_missing_id
      assert_not_requested :put, /fulfil\.io/
      CustomerShipment.new(model_name: CustomerShipment::MODEL_NAME).hold
    end

    def test_uholding_makes_no_request_when_missing_id
      assert_not_requested :put, /fulfil\.io/
      CustomerShipment.new(model_name: CustomerShipment::MODEL_NAME).unhold
    end

    def test_holding_fails_when_fulfil_returns_error
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)

      assert_predicate @customer_shipment.errors, :present?
    end

    def test_unholding_fails_when_fulfil_returns_error
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)

      assert_predicate @customer_shipment.errors, :present?
    end
  end
end
