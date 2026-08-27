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

      def test_default_value_for_request_order
        assert_empty @relation.request_order
      end

      def test_ordering_on_a_single_field_defaults_to_ascending
        assert_equal [%w[create_date ASC]], @relation.order(:create_date).request_order
      end

      def test_ordering_on_a_single_field_with_a_direction
        assert_equal [%w[id DESC]], @relation.order(id: :desc).request_order
      end

      def test_ordering_on_multiple_fields_preserves_their_order
        relation = @relation.order(:create_date, number: :desc)

        assert_equal [%w[create_date ASC], %w[number DESC]], relation.request_order
      end

      def test_ordering_accepts_fulfils_own_format
        assert_equal [%w[id DESC]], @relation.order(%w[id DESC]).request_order
      end

      def test_chaining_order_appends_to_the_existing_sort_order
        relation = @relation.order(:create_date).order(id: :desc)

        assert_equal [%w[create_date ASC], %w[id DESC]], relation.request_order
      end

      def test_ordering_does_not_mutate_the_original_relation
        @relation.order(:create_date)

        assert_empty @relation.request_order
      end

      def test_ordering_on_an_unknown_direction
        error = assert_raises ArgumentError do
          @relation.order(id: :sideways)
        end

        assert_equal 'Unknown order direction "SIDEWAYS". Use :asc or :desc.', error.message
      end
    end
  end
end
