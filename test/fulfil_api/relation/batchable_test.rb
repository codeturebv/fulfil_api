# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Relation
    class BatchableTest < Minitest::Test
      def setup
        @relation = FulfilApi::Resource.set(model_name: "sale.sale")
      end

      def test_finding_individual_resources_effectively
        batch_one = [{ id: 1 }, { id: 2 }]

        stub_request(:put, /fulfil\.io/)
          .and_return(status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" })

        @relation.find_each do |resource|
          assert_includes batch_one.map { _1[:id] }, resource["id"]
        end
      end

      def test_finding_individual_resources_effectively_in_smaller_batches
        batch_one = [{ id: 1 }, { id: 2 }]
        batch_two = [{ id: 3 }, { id: 4 }]
        batch_three = [{ id: 5 }]

        stub_request(:put, /fulfil\.io/)
          .and_return(
            { status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" } },
            { status: 200, body: batch_two.to_json, headers: { "Content-Type": "application/json" } },
            { status: 200, body: batch_three.to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.find_each(batch_size: 2) do |resource|
          assert_includes [1, 2, 3, 4, 5], resource["id"]
        end

        # NOTE: We have three batches. The last one includes less items than the
        #   requested batch size and therefore we will stop querying Fulfil's API.
        assert_requested :put, /fulfil\.io/, times: 3
      end

      def test_finding_multiple_batches
        batch_one = [{ id: 1 }, { id: 2 }, { id: 3 }]

        stub_request(:put, /fulfil\.io/)
          .and_return(status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" })

        @relation.in_batches do |batch|
          assert_kind_of FulfilApi::Relation, batch
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
          assert_kind_of FulfilApi::Relation, batch
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
          assert_kind_of FulfilApi::Relation, batch
        end

        assert_requested :put, /fulfil\.io/, times: 2 do |request|
          assert_equal [["state", "=", "draft"]], JSON.parse(request.body)["filters"]
        end
      end

      def test_finding_no_batch
        stub_request(:put, /fulfil\.io/)
          .and_return(status: 200, body: [].to_json, headers: { "Content-Type": "application/json" })

        @relation.in_batches do |batch|
          assert_kind_of FulfilApi::Relation, batch
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
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } },
            { status: 200, body: batch_two.to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.in_batches(of: 2) do |batch|
          assert_kind_of FulfilApi::Relation, batch
        end

        assert_requested :put, /fulfil\.io/, times: 3
      end

      def test_encountering_a_too_many_request_error_too_many_times_with_default_value
        batch_one = [{ id: 1 }, { id: 2 }]

        stub_request(:put, /fulfil\.io/)
          .and_return(
            { status: 429, body: { error: "Too Many Requests" }.to_json, headers: { "Content-Type": "application/json" } },
            { status: 429, body: { error: "Too Many Requests" }.to_json, headers: { "Content-Type": "application/json" } },
            { status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.in_batches do |batch|
          assert_kind_of FulfilApi::Relation, batch
        end
      end

      def test_encountering_a_too_many_request_error_too_many_times_with_configured_value
        stub_request(:put, /fulfil\.io/)
          .and_return(
            { status: 429, body: { error: "Too Many Requests" }.to_json, headers: { "Content-Type": "application/json" } },
            { status: 429, body: { error: "Too Many Requests" }.to_json, headers: { "Content-Type": "application/json" } }
          )

        assert_raises FulfilApi::Relation::Batchable::RetryLimitExceeded do
          @relation.in_batches(retries: 5) do |batch|
            assert_kind_of FulfilApi::Relation, batch
          end
        end
      end

      def test_encountering_a_regular_http_error
        stub_request(:put, /fulfil\.io/)
          .and_return(
            status: 400,
            body: { error: "something went wrong" }.to_json,
            headers: { "Content-Type": "application/json" }
          )

        assert_raises FulfilApi::Error do
          @relation.in_batches(of: 2) do |batch|
            batch
          end
        end
      end
    end
  end
end
