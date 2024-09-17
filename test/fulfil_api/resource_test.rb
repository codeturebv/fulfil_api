# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class ResourceTest < Minitest::Test
    def test_default_attributes_are_empty
      resource = Resource.new(model_name: "sale.sale")

      assert_empty resource.instance_variable_get(:@attributes)
    end

    def test_presence_of_model_name
      assert_raises Resource::ModelNameMissing do
        Resource.new
      end
    end

    def test_assignment_of_attributes
      attributes = { warehouse: 10, model_name: "sale.sale" }
      resource = Resource.new(attributes)

      assert_equal({ "warehouse" => 10 }, resource.instance_variable_get(:@attributes))
    end

    def test_accessing_attribute_by_stringified_attribute_name
      resource = Resource.new({ warehouse: 10, model_name: "sale.sale" })

      assert_equal 10, resource["warehouse"]
    end

    def test_accessing_attribute_by_symbolized_attribute_name
      resource = Resource.new({ warehouse: 10, model_name: "sale.sale" })

      assert_equal 10, resource[:warehouse]
    end

    def test_shorthand_for_id
      assert_equal 10, Resource.new({ id: 10, model_name: "sale.sale" }).id
      assert_nil Resource.new({ model_name: "sale.sale" }).id
    end

    def test_rendering_all_attributes_as_hash
      resource = Resource.new({ warehouse: 10, model_name: "sale.sale" })

      assert_equal({ "warehouse" => 10 }, resource.to_h)
    end
  end
end
