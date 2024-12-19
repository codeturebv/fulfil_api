# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class QueryableTest < Minitest::Test
      def setup
        @resource = FulfilApi::Resource.new(model_name: "sale.sale", id: rand(1..100))
      end

      def test_turning_json_into_resource
        json = { "id" => @resource.id, "model_name" => "sale.sale" }.to_json

        assert_equal @resource, FulfilApi::Resource.from_json(json)
      end

      def test_turning_json_into_resource_without_model_name
        json = { "id" => @resource.id }.to_json

        assert_raises FulfilApi::Resource::ModelNameMissing do
          FulfilApi::Resource.from_json(json)
        end
      end

      def test_turning_json_into_resource_with_root_included
        json = { "sales_order" => { "id" => @resource.id, "model_name" => "sale.sale" } }.to_json

        assert_equal @resource, FulfilApi::Resource.from_json(json, root_included: true)
      end

      def test_preparing_to_be_jsonified
        assert_equal(
          { "id" => @resource.id, "model_name" => "sale.sale" },
          @resource.as_json
        )
      end

      def test_preparing_to_be_jsonified_with_root_included
        assert_equal(
          { "sales_order" => { "id" => @resource.id, "model_name" => "sale.sale" } },
          @resource.as_json(root: "sales_order")
        )
      end

      def test_turning_resource_into_json
        assert_equal(
          { "id" => @resource.id, "model_name" => "sale.sale" }.to_json,
          @resource.to_json
        )
      end
    end
  end
end
