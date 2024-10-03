# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class CustomerShipmentTest < Minitest::Test
    def setup
      @customer_shipment = CustomerShipment.new(id: 123, model_name: CustomerShipment::MODEL_NAME)
    end

    def test_holding_shipment_successfully_from_instance
      stub_fulfil_request(:put, response: nil)

      assert @customer_shipment.hold("Wait until default hold period expired")
    end

    def test_holding_shipment_successfully_from_class
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.hold!(123, note: "Wait until default hold period expired")
    end

    def test_holding_shipments_successfully_from_class
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.hold!([123, 456], note: "Hold all until default hold period expired")
    end

    def test_unholding_shipment_successfully_from_instance
      stub_fulfil_request(:put, response: nil)

      assert @customer_shipment.unhold("The wait is over")
    end

    def test_unholding_shipment_successfully_from_class
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.unhold!(123, note: "The wait is over")
    end

    def test_unholding_shipments_successfully_from_class
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.unhold!([123, 456], note: "The wait for all shipments is over")
    end

    def test_ensure_correct_body_for_holding_shipment
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.hold!(123, note: "Double booking")

      assert_requested :put, /fulfil\.io/ do |request|
        assert_equal [[123], "Double booking"], JSON.parse(request.body)
      end
    end

    def test_ensure_correct_body_for_holding_shipments
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.hold!([123, 456], note: "Double booking")

      assert_requested :put, /fulfil\.io/ do |request|
        assert_equal [[123, 456], "Double booking"], JSON.parse(request.body)
      end
    end

    def test_ensure_correct_body_for_unholding_shipment
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.unhold!(123, note: "Issue has been resolved")

      assert_requested :put, /fulfil\.io/ do |request|
        assert_equal [[123], "Issue has been resolved"], JSON.parse(request.body)
      end
    end

    def test_ensure_correct_body_for_unholding_shipments
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.unhold!([123, 456], note: "The issues have been resolved")

      assert_requested :put, /fulfil\.io/ do |request|
        assert_equal [[123, 456], "The issues have been resolved"], JSON.parse(request.body)
      end
    end

    def test_raises_error_when_holding_customer_shipment_fails_from_class
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)

      assert_raises FulfilApi::Error do
        CustomerShipment.hold!(123, note: "Please hold off shipping this shipment")
      end
    end

    def test_raises_error_when_unholding_customer_shipment_fails_from_class
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)

      assert_raises FulfilApi::Error do
        CustomerShipment.unhold!(123, note: "Ship out this shipment")
      end
    end

    def test_holding_fails_when_fulfil_returns_error
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)
      @customer_shipment.hold("Please hold off shipping this shipment")

      assert_predicate @customer_shipment.errors, :present?
    end

    def test_unholding_fails_when_fulfil_returns_error
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)
      @customer_shipment.unhold("Ship out this shipment")

      assert_predicate @customer_shipment.errors, :present?
    end
  end
end
