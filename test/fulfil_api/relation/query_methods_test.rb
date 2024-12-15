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
    end
  end
end
