# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Relation
    class BatchableTest < Minitest::Test
      def setup
        super
        @relation = FulfilApi::Resource.set(model_name: "sale.sale")

        # Record the waits between retries instead of actually sleeping through them.
        @waits = waits = []
        @original_pause = Batchable.method(:pause)
        Batchable.define_singleton_method(:pause) { |seconds| waits << seconds }
      end

      def teardown
        Batchable.define_singleton_method(:pause, @original_pause)
        super
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
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } },
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } },
            { status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.in_batches do |batch|
          assert_kind_of FulfilApi::Relation, batch
        end
      end

      def test_encountering_a_too_many_request_error_too_many_times_with_configured_value
        stub_request(:put, /fulfil\.io/)
          .and_return(
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } },
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } }
          )

        assert_raises FulfilApi::Relation::Batchable::RetryLimitExceeded do
          @relation.in_batches(retries: 2) do |batch|
            assert_kind_of FulfilApi::Relation, batch
          end
        end

        assert_requested :put, /fulfil\.io/, times: 4
      end

      def test_encountering_a_too_many_request_errors_and_successfull_requests
        batch_one = [{ id: 1 }]

        stub_request(:put, /fulfil\.io/)
          .and_return(
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } },
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } },
            { status: 200, body: batch_one.to_json, headers: { "Content-Type": "application/json" } },
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } },
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } },
            { status: 429, body: { error: "Too Many Requests" }.to_json,
              headers: { "Content-Type": "application/json" } }
          )

        assert_raises FulfilApi::Relation::Batchable::RetryLimitExceeded do
          @relation.in_batches(of: 1, retries: 3) do |batch|
            assert_kind_of FulfilApi::Relation, batch
          end
        end

        assert_requested :put, /fulfil\.io/, times: 8
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

      def test_waiting_longer_after_every_retry
        stub_request(:put, /fulfil\.io/)
          .and_return(
            *Array.new(3) { too_many_requests },
            { status: 200, body: [{ id: 1 }].to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.in_batches { |batch| batch }

        assert_equal 3, @waits.size
        assert_includes 0.25..0.5, @waits[0]
        assert_includes 0.5..1.0, @waits[1]
        assert_includes 1.0..2.0, @waits[2]
      end

      def test_never_waiting_longer_than_the_maximum
        stub_request(:put, /fulfil\.io/)
          .and_return(
            *Array.new(10) { too_many_requests },
            { status: 200, body: [{ id: 1 }].to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.in_batches { |batch| batch }

        assert(@waits.all? { |wait| wait <= Batchable::RETRY_MAX_WAIT })
      end

      def test_waiting_as_long_as_fulfil_asks
        stub_request(:put, /fulfil\.io/)
          .and_return(
            too_many_requests(headers: { "Retry-After" => "7" }),
            { status: 200, body: [{ id: 1 }].to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.in_batches { |batch| batch }

        assert_equal [7], @waits
      end

      def test_waiting_until_fulfil_resets_its_rate_limit
        stub_request(:put, /fulfil\.io/)
          .and_return(
            too_many_requests(headers: { "X-RateLimit-Reset" => (Time.now.to_i + 3).to_s }),
            { status: 200, body: [{ id: 1 }].to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.in_batches { |batch| batch }

        assert_includes 2..3, @waits.first
      end

      def test_capping_the_wait_fulfil_asks_for
        stub_request(:put, /fulfil\.io/)
          .and_return(
            too_many_requests(headers: { "Retry-After" => "120" }),
            { status: 200, body: [{ id: 1 }].to_json, headers: { "Content-Type": "application/json" } }
          )

        @relation.in_batches { |batch| batch }

        assert_equal [Batchable::RETRY_MAX_WAIT], @waits
      end

      private

      def too_many_requests(headers: {})
        { status: 429, body: { error: "Too Many Requests" }.to_json,
          headers: { "Content-Type": "application/json" }.merge(headers) }
      end
    end
  end
end
