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

    def test_digging_into_a_nested_attribute
      resource = Resource.new({ "sale.party.name" => "Freddie Mercury", model_name: "sale.line" })

      assert_equal "Freddie Mercury", resource.dig("sale", "party", "name")
    end

    def test_digging_with_symbolized_attribute_names
      resource = Resource.new({ "sale.party.name" => "Freddie Mercury", model_name: "sale.line" })

      assert_equal "Freddie Mercury", resource.dig(:sale, :party, :name)
    end

    def test_digging_into_an_attribute_that_is_missing
      resource = Resource.new({ warehouse: 10, model_name: "sale.sale" })

      assert_nil resource.dig("sale", "party", "name")
    end

    def test_digging_into_a_single_attribute
      resource = Resource.new({ warehouse: 10, model_name: "sale.sale" })

      # Deliberately the single argument form, which has to keep behaving like #[].
      assert_equal 10, resource.dig("warehouse") # rubocop:disable Style/SingleArgumentDig
    end

    def test_fetching_an_attribute
      resource = Resource.new({ warehouse: 10, model_name: "sale.sale" })

      assert_equal 10, resource.fetch("warehouse")
      assert_equal 10, resource.fetch(:warehouse)
    end

    def test_fetching_an_attribute_that_is_missing
      resource = Resource.new({ model_name: "sale.sale" })

      assert_raises KeyError do
        resource.fetch("warehouse")
      end
    end

    def test_fetching_an_attribute_that_is_missing_with_a_default
      resource = Resource.new({ model_name: "sale.sale" })

      assert_equal 25, resource.fetch("warehouse", 25)
      assert_equal 25, resource.fetch("warehouse") { 25 } # rubocop:disable Style/RedundantFetchBlock
    end

    def test_checking_for_the_presence_of_an_attribute
      resource = Resource.new({ warehouse: 10, model_name: "sale.sale" })

      assert resource.key?("warehouse")
      assert resource.key?(:warehouse)
      refute resource.key?("reference")
    end

    def test_rendering_all_attributes_as_hash
      resource = Resource.new({ warehouse: 10, model_name: "sale.sale" })

      assert_equal({ "warehouse" => 10 }, resource.to_h)
    end
  end
end
