# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Relation
    class LoadableTest < Minitest::Test
      def setup
        @relation = Relation.new(FulfilApi::Resource)
      end

      def test_loading_resources_without_defined_name
        assert_raises FulfilApi::Resource::ModelNameMissing do
          @relation.load
        end
      end

      def test_loading_all_resources_with_provided_query_values
        stub_fulfil_request(:put, response: [{ id: 100 }], model: "sale.sale")

        @relation
          .set(model_name: "sale.sale")
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

        sales_orders = @relation.set(model_name: "sale.sale")

        sales_orders.load # This will load the resources from the API.
        sales_orders.load # This won't trigger an additional HTTP request as it's already loaded
        sales_orders.load # This won't trigger an additional HTTP request either as it's already loaded

        assert_requested :put, %r{sale.sale/search_read}i, times: 1
      end

      def test_default_loaded_check
        refute_predicate @relation, :loaded?
      end

      def test_loading_resources_marks_relation_as_loaded
        stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

        sales_orders = @relation.set(model_name: "sale.sale")

        refute_predicate sales_orders, :loaded?

        sales_orders.load

        assert_predicate sales_orders, :loaded?
      end

      def test_reloading_resources_from_the_api
        stub_fulfil_request(:put, response: [{ id: 100 }, { id: 200 }, { id: 300 }], model: "sale.sale")

        sales_orders = @relation.set(model_name: "sale.sale")

        sales_orders.load # This causes the sales orders to be loaded first.
        sales_orders.reload # This causes the sales orders to be reloaded from the API.

        assert_requested :put, %r{sale.sale/search_read}i, times: 2
      end

      def test_loading_the_relation_with_an_offset
        stub_fulfil_request(:put, response: [{ id: 100 }], model: "sale.sale")

        @relation.set(model_name: "sale.sale").offset(5).load

        assert_requested :put, %r{sale.sale/search_read}i do |request|
          assert_equal 5, JSON.parse(request.body)["offset"]
        end
      end
    end
  end
end
