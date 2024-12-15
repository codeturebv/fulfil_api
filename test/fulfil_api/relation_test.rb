# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class RelationTest < Minitest::Test
    def setup
      @relation = Relation.new(FulfilApi::Resource)
    end

    def test_all_returns_found_resources
      stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

      sales_orders = @relation.set(model_name: "sale.sale").all

      assert sales_orders.all?(FulfilApi::Resource)
    end

    def test_iterating_over_resources_when_not_loaded
      stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

      assert_not_requested :put, %r{sale.sale/search_read}i, times: 1

      @relation.set(model_name: "sale.sale").each do |sales_order|
        assert_kind_of FulfilApi::Resource, sales_order
      end

      assert_requested :put, %r{sale.sale/search_read}i, times: 1
    end

    def test_default_offset_value
      assert_nil @relation.request_offset # By default, we don't have an offset and let Fulfil set the limit (zero).
    end

    def test_default_limit_value
      assert_nil @relation.request_limit # By default, we don't have a limit and let Fulfil set the limit (500).
    end

    def test_setting_resource_number_limits_multiple_times
      chained_relation = @relation.limit(10)
      chained_relation = chained_relation.limit(50)
      chained_relation = chained_relation.limit(5)

      assert_equal 5, chained_relation.request_limit
    end

    def test_default_api_fields_for_selection
      assert_equal %w[id], @relation.fields
    end

    def test_selecting_api_resource_attributes
      default_fields = %w[id]

      assert_equal(
        default_fields + ["reference", "sale.reference"],
        @relation.select(:reference, "sale.reference").fields
      )
    end

    def test_setting_the_name
      assert_equal "sale.sale", @relation.set(model_name: "sale.sale").model_name
    end

    def test_building_filter_options
      assert_equal [["id", "=", 100]], @relation.where(["id", "=", 100]).conditions
    end

    def test_only_unique_filter_options
      chained_relation = @relation.where(["id", "=", 100])
      chained_relation = chained_relation.where(["id", "=", 100])
      chained_relation = chained_relation.where(["line.code", "ilike", "SKU-%"])

      assert_equal [["id", "=", 100], ["line.code", "ilike", "SKU-%"]], chained_relation.conditions
    end

    def test_flattening_purposely_nested_arrays_when_querying
      assert_equal [["id", "in", [10, 20]]], @relation.where(["id", "in", [10, 20]]).conditions
    end
  end
end
