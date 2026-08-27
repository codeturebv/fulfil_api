# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class InteractiveReportTest < Minitest::Test
    def setup
      @merchant_id = "merchant-#{SecureRandom.uuid}"

      FulfilApi.configure do |config|
        config.merchant_id = @merchant_id
        config.access_token = FulfilApi::AccessToken.new(SecureRandom.uuid)
      end
    end

    def test_execute_makes_a_put_request_to_the_report_endpoint
      stub_fulfil_request(:put, response: [], model: "inventory.quantity.ireport", suffix: "execute")

      FulfilApi::InteractiveReport.execute("inventory.quantity.ireport", warehouse: 12)

      assert_requested :put, %r{#{@merchant_id}.fulfil.io/api/v2/model/inventory.quantity.ireport/execute}i
    end

    def test_execute_wraps_the_parameters_in_an_array
      stub_fulfil_request(:put, response: [], model: "inventory.quantity.ireport", suffix: "execute")

      FulfilApi::InteractiveReport.execute("inventory.quantity.ireport", warehouse: 12, show_products: "all")

      assert_requested :put, %r{inventory.quantity.ireport/execute}i do |request|
        assert_equal [{ "warehouse" => 12, "show_products" => "all" }], JSON.parse(request.body)
      end
    end

    def test_execute_serializes_dates_in_fulfils_extended_json_format
      stub_fulfil_request(:put, response: [], model: "inventory.quantity.ireport", suffix: "execute")

      FulfilApi::InteractiveReport.execute("inventory.quantity.ireport", start_date: Date.new(2026, 8, 27))

      assert_requested :put, %r{inventory.quantity.ireport/execute}i do |request|
        assert_equal(
          [{ "start_date" => { "__class__" => "date", "year" => 2026, "month" => 8, "day" => 27 } }],
          JSON.parse(request.body)
        )
      end
    end

    def test_execute_returns_the_raw_result_of_the_report
      stub_fulfil_request(:put, response: [%w[header sku], ["data", [{ "sku" => "MK-123" }]]],
                                model: "inventory.quantity.ireport", suffix: "execute")

      result = FulfilApi::InteractiveReport.execute("inventory.quantity.ireport", warehouse: 12)

      assert_equal [%w[header sku], ["data", [{ "sku" => "MK-123" }]]], result
    end

    def test_execute_can_be_called_on_a_reusable_instance
      stub_fulfil_request(:put, response: [], model: "inventory.quantity.ireport", suffix: "execute")

      report = FulfilApi::InteractiveReport.new("inventory.quantity.ireport")
      report.execute(warehouse: 12)
      report.execute(warehouse: 13)

      assert_requested :put, %r{inventory.quantity.ireport/execute}i, times: 2
    end
  end
end
