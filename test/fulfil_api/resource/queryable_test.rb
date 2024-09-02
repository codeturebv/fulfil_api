# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class QueryableTest < Minitest::Test
      def test_duplication_of_chained_relation_requests
        first_request = FulfilApi::Resource.where(["id", "=", 100])
        second_request = first_request.where(["id", "=", 200])

        refute_same first_request, second_request
        assert_kind_of FulfilApi::Resource::Relation, first_request
      end

      def test_chainability_of_request_options
        request = FulfilApi::Resource.set(name: "sale.sale").where(["id", "=", 100]).limit(50)

        assert_equal [["id", "=", 100]], request.conditions
        assert_equal "sale.sale", request.name
        assert_equal 50, request.request_limit
      end

      def test_deffering_http_request_until_enumeration_actions
        stub_fulfil_request(:put, model: "sale.sale")

        request = FulfilApi::Resource.set(name: "sale.sale").where(["id", "=", 100]).limit(50)

        assert_not_requested :put, %r{sale.sale/search_read}i

        request.any?

        assert_requested :put, %r{sale.sale/search_read}i
      end
    end
  end
end
