# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class CustomerShipmentTest < Minitest::Test
    def setup
      @customer_shipment = CustomerShipment.new(id: 123, model_name: CustomerShipment::MODEL_NAME)
    end

    def test_holding_shipment_successfully_from_instance
      stub_fulfil_request(:put, response: nil)

      assert @customer_shipment.hold
    end

    def test_holding_shipment_successfully_from_class
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.hold!(123)
    end

    def test_holding_shipments_successfully_from_class
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.hold!([123, 456])
    end

    def test_unholding_shipment_successfully_from_instance
      stub_fulfil_request(:put, response: nil)

      assert @customer_shipment.unhold
    end

    def test_unholding_shipment_successfully_from_class
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.unhold!(123)
    end

    def test_unholding_shipments_successfully_from_class
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.unhold!([123, 456])
    end

    def test_ensure_correct_body_for_holding_shipment
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.hold!(123, note: "Double booking")

      assert_requested :put, /fulfil\.io/ do |request|
        assert_equal [[123], { "note" => "Double booking" }], JSON.parse(request.body)
      end
    end

    def test_ensure_correct_body_for_holding_shipments
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.hold!([123, 456], note: "Double booking")

      assert_requested :put, /fulfil\.io/ do |request|
        assert_equal [[123, 456], { "note" => "Double booking" }], JSON.parse(request.body)
      end
    end

    def test_ensure_correct_body_for_unholding_shipment
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.unhold!(123, note: "All good!")

      assert_requested :put, /fulfil\.io/ do |request|
        assert_equal [[123], { "note" => "All good!" }], JSON.parse(request.body)
      end
    end

    def test_ensure_correct_body_for_unholding_shipments
      stub_fulfil_request(:put, response: nil)

      assert CustomerShipment.unhold!([123, 456], note: "All good!")

      assert_requested :put, /fulfil\.io/ do |request|
        assert_equal [[123, 456], { "note" => "All good!" }], JSON.parse(request.body)
      end
    end

    def test_raises_error_when_holding_customer_shipment_fails_from_class
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)

      assert_raises FulfilApi::Error do
        CustomerShipment.hold!(123)
      end
    end

    def test_raises_error_when_unholding_customer_shipment_fails_from_class
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)

      assert_raises FulfilApi::Error do
        CustomerShipment.unhold!(123)
      end
    end

    def test_holding_fails_when_fulfil_returns_error
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)
      @customer_shipment.hold

      assert_predicate @customer_shipment.errors, :present?
    end

    def test_unholding_fails_when_fulfil_returns_error
      stub_fulfil_request(:put, response: { body: { message: "Missing Attributes" } }, status: 500)
      @customer_shipment.unhold

      assert_predicate @customer_shipment.errors, :present?
    end
  end
end
