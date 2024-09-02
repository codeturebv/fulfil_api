# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class RelationTest < Minitest::Test
      def setup
        @relation = Relation.new(FulfilApi::Resource)
      end

      def test_all_returns_found_resources
        stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

        sales_orders = @relation.set(name: "sale.sale").all

        assert sales_orders.all?(FulfilApi::Resource)
      end

      def test_iterating_over_resources_when_not_loaded
        stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

        assert_not_requested :put, %r{sale.sale/search_read}i, times: 1

        @relation.set(name: "sale.sale").each do |sales_order|
          assert_kind_of FulfilApi::Resource, sales_order
        end

        assert_requested :put, %r{sale.sale/search_read}i, times: 1
      end

      def test_loading_all_resources_with_provided_query_values
        stub_fulfil_request(:put, response: [{ id: 100 }], model: "sale.sale")

        @relation
          .set(name: "sale.sale")
          .select("name", "reference")
          .where(["id", "=", 100])
          .limit(10)
          .load

        assert_requested :put, %r{sale.sale/search_read}i do |request|
          parsed_body = JSON.parse(request.body)

          assert_equal [["id", "=", 100]], parsed_body["filters"]
          assert_equal %w[id name reference], parsed_body["fields"]
          assert_equal 10, parsed_body["limit"]
        end
      end

      def test_caching_for_consecutive_loads
        stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

        sales_orders = @relation.set(name: "sale.sale")

        sales_orders.load # This will load the resources from the API.
        sales_orders.load # This won't trigger an additional HTTP request as it's already loaded
        sales_orders.load # This won't trigger an additional HTTP request either as it's already loaded

        assert_requested :put, %r{sale.sale/search_read}i, times: 1
      end

      def test_loading_resources_marks_relation_as_loaded
        stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

        sales_orders = @relation.set(name: "sale.sale")

        refute_predicate sales_orders, :loaded?

        sales_orders.load

        assert_predicate sales_orders, :loaded?
      end

      def test_loading_resources_without_defined_name
        assert_raises FulfilApi::Resource::Relation::ModelNameMissing do
          @relation.load
        end
      end

      def test_default_loaded_check
        refute_predicate @relation, :loaded?
      end

      def test_default_limit_for_fetching_data
        assert_nil @relation.request_limit # By default, we don't have a limit and let Fulfil set the limit.
      end

      def test_fetching_limited_resources
        assert_equal 10, @relation.limit(10).request_limit
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
        assert_equal "sale.sale", @relation.set(name: "sale.sale").name
      end

      def test_reloading_resources_from_the_api
        stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

        sales_orders = @relation.set(name: "sale.sale")

        sales_orders.load # This causes the sales orders to be loaded first.
        sales_orders.reload # This causes the sales orders to be reloaded from the API.

        assert_requested :put, %r{sale.sale/search_read}i, times: 2
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

      def test_flattening_to_deeply_nested_arrays_when_querying
        assert_equal [["id", "=", 100]], @relation.where([["id", "=", 100]]).conditions
      end
    end
  end
end
