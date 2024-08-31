# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class AttributeTypeTest < Minitest::Test
      def test_casting_date_attribute_values
        raw_value = { "__class__" => "date", "iso_string" => "2020-12-12" }
        value = AttributeType.cast(raw_value)

        assert_kind_of Date, value
        assert_equal Date.new(2020, 12, 12), value
      end

      def test_casting_datetime_attribute_values
        raw_value = { "__class__" => "datetime", "iso_string" => "2020-12-12T16:30:25" }
        value = AttributeType.cast(raw_value)

        assert_kind_of DateTime, value
        assert_equal DateTime.new(2020, 12, 12, 16, 30, 25), value
      end

      def test_casting_float_attribute_values
        raw_value = 10.50
        value = AttributeType.cast(raw_value)

        assert_kind_of Float, value
        assert_in_delta 10.50, value
      end

      def test_casting_regular_hash_attribute_values
        raw_value = { "id" => 10 }
        value = AttributeType.cast(raw_value)

        assert_kind_of Hash, value
        assert_equal raw_value, value
      end

      def test_casting_integer_attribute_values
        raw_value = 100_000
        value = AttributeType.cast(raw_value)

        assert_kind_of Integer, value
        assert_equal 100_000, value
      end

      def test_casting_string_attribute_values
        raw_value = "Main Warehouse"
        value = AttributeType.cast(raw_value)

        assert_kind_of String, value
        assert_equal "Main Warehouse", value
      end

      def test_casting_time_attribute_values
        raw_value = { "__class__" => "time", "iso_string" => "16:30:25" }
        value = AttributeType.cast(raw_value)

        assert_kind_of Time, value
        assert_equal Time.parse("16:30:25"), value
      end

      def test_casting_numeric_attribute_values
        raw_value = { "__class__" => "decimal", "decimal" => "12.50256" }
        value = AttributeType.cast(raw_value)

        assert_kind_of BigDecimal, value
        assert_equal BigDecimal("12.50256"), value
      end

      def test_casting_binary_attribute_values
        raw_value = { "__class__" => "bytes", "base64" => "aGVsbG93b3JsZA==\\n" }
        value = AttributeType.cast(raw_value)

        assert_equal Base64.decode64("aGVsbG93b3JsZA==\\n"), value
      end
    end
  end
end
