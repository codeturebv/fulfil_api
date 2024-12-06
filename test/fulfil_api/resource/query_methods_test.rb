# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class QueryMethodsTest < Minitest::Test
      def setup
        @relation = FulfilApi::Resource.set(model_name: "sale.sale")
      end

      def test_find_by_returns_found_resource
        stub_fulfil_request(:put, response: [{ id: 100 }])

        sales_order = @relation.find_by(["id", "=", 100])

        assert_equal 100, sales_order["id"]
      end

      def test_find_by_sets_return_limit_to_one
        stub_fulfil_request(:put, response: [{ id: 100 }], model: "sale.sale")

        @relation.set(model_name: "sale.sale").find_by(["id", "=", 100])

        assert_requested :put, %r{sale.sale/search_read}i do |request|
          parsed_body = JSON.parse(request.body)

          assert_equal [["id", "=", 100]], parsed_body["filters"]
          assert_equal 1, parsed_body["limit"] # The limit is set to one to ensure only one resource is requested
        end
      end

      def test_find_by_returns_nil_when_nothing_found
        stub_fulfil_request(:put, response: [])

        assert_nil @relation.find_by(["id", "=", 10])
      end

      def test_find_by_bang_raises_when_nothing_found
        stub_fulfil_request(:put, response: [])

        assert_raises FulfilApi::Resource::NotFound do
          @relation.find_by!(["id", "=", 10])
        end
      end
    end
  end
end
