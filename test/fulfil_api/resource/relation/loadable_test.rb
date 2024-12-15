# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class Relation
      class LoadableTest < Minitest::Test
        def setup
          @relation = Relation.new(FulfilApi::Resource)
        end

        def test_default_offset_value
          assert_nil @relation.request_offset
        end

        def test_loading_the_relation_with_an_offset
          stub_fulfil_request(:put, response: [{ id: 100 }], model: "sale.sale")

          @relation.set(model_name: "sale.sale").offset(5).load

          assert_requested :put, %r{sale.sale/search_read}i do |request|
            assert_equal 5, JSON.parse(request.body)["offset"]
          end
        end
      end
    end
  end
end
