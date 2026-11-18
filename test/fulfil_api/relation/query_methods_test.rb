# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Relation
    class QueryMethodsTest < Minitest::Test
      def setup
        @relation = FulfilApi::Resource.set(model_name: "sale.sale")
      end

      def test_setting_a_request_offset
        offset_value = rand(2..25)

        assert_equal offset_value, @relation.offset(offset_value).request_offset
      end

      def test_default_value_for_request_offset
        assert_nil @relation.request_offset
      end

      def test_where_leaves_the_relation_it_builds_on_as_it_was
        @relation.where(["state", "=", "done"])

        assert_empty @relation.conditions
      end

      def test_select_leaves_the_relation_it_builds_on_as_it_was
        @relation.select(:reference)

        assert_equal %w[id], @relation.fields
      end

      def test_relations_built_on_the_same_relation_only_send_their_own_conditions
        stub_fulfil_request(:put, model: "sale.sale", response: [])

        @relation.where(["state", "=", "draft"]).to_a
        @relation.where(["state", "=", "done"]).to_a

        assert_requested(:put, %r{sale\.sale/search_read}, times: 1) do |request|
          JSON.parse(request.body)["filters"] == [["state", "=", "done"]]
        end
      end
    end
  end
end
