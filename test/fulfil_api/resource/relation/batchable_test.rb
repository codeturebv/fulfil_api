# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class Relation
      class BatchableTest < Minitest::Test
        def setup
          @relation = FulfilApi::Resource.set(model_name: "sale.sale")
        end

        def test_finding_multiple_batches
          batch_one = [{ id: 1 }, { id: 2 }, { id: 3 }]

          stub_request(:put, /fulfil\.io/)
            .and_return(status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" })

          @relation.in_batches do |batch|
            assert_kind_of FulfilApi::Resource::Relation, batch
          end

          assert_requested :put, /fulfil\.io/, times: 1
        end

        def test_setting_a_non_standard_batch_size
          batch_size = 2
          batch_one = [{ id: 1 }, { id: 2 }]
          batch_two = [{ id: 3 }, { id: 4 }]
          batch_three = [{ id: 5 }]

          stub_request(:put, /fulfil\.io/)
            .and_return(
              { status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" } },
              { status: 200, body: batch_two.to_json, headers: { "Content-Type": "application/json" } },
              { status: 200, body: batch_three.to_json, headers: { "Content-Type": "application/json" } }
            )

          @relation.in_batches(of: batch_size) do |batch|
            assert_kind_of FulfilApi::Resource::Relation, batch
          end

          # NOTE: We have three batches. The last one includes less items than the
          #   requested batch size and therefore we will stop querying Fulfil's API.
          assert_requested :put, /fulfil\.io/, times: 3
        end

        def test_maintaining_filter_conditions_while_batching
          batch_one = [{ id: 1 }, { id: 2 }]
          batch_two = [{ id: 3 }]

          stub_request(:put, /fulfil\.io/)
            .and_return(
              { status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" } },
              { status: 200, body: batch_two.to_json, headers: { "Content-Type": "application/json" } }
            )

          @relation.where(["state", "=", "draft"]).in_batches(of: 2) do |batch|
            assert_kind_of FulfilApi::Resource::Relation, batch
          end

          assert_requested :put, /fulfil\.io/, times: 2 do |request|
            assert_equal [["state", "=", "draft"]], JSON.parse(request.body)["filters"]
          end
        end

        def test_finding_no_batch
          stub_request(:put, /fulfil\.io/)
            .and_return(status: 200, body: [].to_json, headers: { "Content-Type": "application/json" })

          @relation.in_batches do |batch|
            assert_kind_of FulfilApi::Resource::Relation, batch
            assert_equal 0, batch.size
          end

          assert_requested :put, /fulfil\.io/, times: 1
        end

        def test_encountering_a_too_many_request_error
          batch_one = [{ id: 1 }, { id: 2 }]
          batch_two = [{ id: 3 }]

          stub_request(:put, /fulfil\.io/)
            .and_return(
              { status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" } },
              { status: 429, body: { error: "Too Many Requests" }.to_json, headers: { "Content-Type": "application/json" } },
              { status: 200, body: batch_two.to_json, headers: { "Content-Type": "application/json" } }
            )

          @relation.in_batches(of: 2) do |batch|
            assert_kind_of FulfilApi::Resource::Relation, batch
          end

          assert_requested :put, /fulfil\.io/, times: 3
        end
      end
    end
  end
end
