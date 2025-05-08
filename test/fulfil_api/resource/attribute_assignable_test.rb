# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class AttributeAssignableTest < Minitest::Test
      class Dummy
        include FulfilApi::Resource::AttributeAssignable

        attr_reader :attributes

        def initialize(attributes = {})
          @attributes = attributes
        end
      end

      def setup
        @resource = Dummy.new
      end

      def test_assigning_an_attribute
        raw_value = "Main Warehouse"
        @resource.assign_attribute("warehouse_name", raw_value)

        assert_equal raw_value, @resource.attributes["warehouse_name"]
      end

      def test_assigning_a_nested_attribute
        @resource.assign_attribute("warehouse.id", 10)

        assert_equal 10, @resource.attributes["warehouse"]["id"]
      end

      def test_assigning_an_attribute_with_nested_hash
        raw_value = { level_one: { level_two: { level_three: "level_four" } } }
        @resource.assign_attribute(:hash, raw_value)

        assert_equal(
          { "level_one" => { "level_two" => { "level_three" => "level_four" } } },
          @resource.attributes["hash"]
        )
      end

      def test_assigning_attribute_names_for_nested_arrays
        raw_value = { fields: [{ key: "value" }] }
        @resource.assign_attribute(:array, raw_value)

        assert_equal({ "fields" => [{ "key" => "value" }] }, @resource.attributes["array"])
      end

      def test_assigning_multiple_attributes_simultaneously
        raw_values = { id: 1, warehouse_name: "Main Warehouse" }
        @resource.assign_attributes(raw_values)

        assert_equal raw_values[:warehouse_name], @resource.attributes["warehouse_name"]
        assert_equal raw_values[:id], @resource.attributes["id"]
      end

      def test_extending_existing_attributes
        raw_values = { warehouse: { id: 10 } }
        @resource.assign_attribute("existing_attribute", raw_values)

        assert_equal({ "warehouse" => { "id" => 10 } }, @resource.attributes["existing_attribute"])

        @resource.assign_attribute("existing_attribute", { warehouse: { name: "Main Warehouse" } })

        assert_equal(
          { "warehouse" => { "id" => 10, "name" => "Main Warehouse" } },
          @resource.attributes["existing_attribute"]
        )
      end

      def test_overwriting_existing_attributes
        raw_values = { warehouse: { id: 10 } }
        @resource.assign_attribute("existing_attribute", raw_values)

        assert_equal({ "warehouse" => { "id" => 10 } }, @resource.attributes["existing_attribute"])

        @resource.assign_attribute("existing_attribute", { warehouse: { id: 15 } })

        assert_equal({ "warehouse" => { "id" => 15 } }, @resource.attributes["existing_attribute"])
      end

      def test_assigning_a_nested_relation
        raw_values = { "warehouse" => 10, "warehouse.name" => "Toronto" }
        @resource.assign_attributes(raw_values)

        assert_equal({ "warehouse" => { "id" => 10, "name" => "Toronto" } }, @resource.attributes)
      end

      def test_assigning_a_nested_relation_with_a_string_as_id
        raw_values = { "shipment" => "stock.shipment.out,10", "shipment.number" => "CS1234" }
        @resource.assign_attributes(raw_values)

        assert_equal({ "shipment" => { "id" => 10, "number" => "CS1234" } }, @resource.attributes)
      end

      def test_assigning_a_nested_relation_in_reverse_order
        raw_values = { "warehouse.name" => "Toronto", "warehouse" => 10 }
        @resource.assign_attributes(raw_values)

        assert_equal({ "warehouse" => { "name" => "Toronto", "id" => 10 } }, @resource.attributes)
      end

      def test_assigning_a_nested_relation_with_a_string_as_id_in_reverse_order
        raw_values = { "shipment.number" => "CS1234", "shipment" => "stock.shipment.out,10" }
        @resource.assign_attributes(raw_values)

        assert_equal({ "shipment" => { "id" => 10, "number" => "CS1234" } }, @resource.attributes)
      end

      def test_assigning_a_nested_relation_in_mixed_order
        raw_values = { "warehouse.name" => "Toronto", "warehouse" => 10, "warehouse.active" => true }
        @resource.assign_attributes(raw_values)

        assert_equal({ "warehouse" => { "name" => "Toronto", "id" => 10, "active" => true } }, @resource.attributes)
      end

      def test_assigning_a_nested_relation_with_a_string_as_id_in_mixed_order
        raw_values = {
          "shipment.number" => "CS1234",
          "shipment" => "stock.shipment.out,10",
          "shipment.origin" => "sale.sale,1"
        }
        @resource.assign_attributes(raw_values)

        assert_equal(
          { "shipment" => { "id" => 10, "number" => "CS1234", "origin" => "sale.sale,1" } },
          @resource.attributes
        )
      end

    end
  end
end
