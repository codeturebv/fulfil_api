# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class Relation
      class CountableTest < Minitest::Test
        def setup
          @relation = FulfilApi::Resource.set(model_name: "sale.sale")
        end

        def test_returns_the_number_of_found_resources_in_fulfil
          number_of_resources = rand(1..99)
          stub_fulfil_request(:put, model: "sale.sale", suffix: "search_count", response: number_of_resources)

          assert_equal number_of_resources, @relation.count
        end

        def test_includes_any_provided_filtering_conditions_when_counting_resources
          stub_fulfil_request(:put, model: "sale.sale", suffix: "search_count", response: 10)

          @relation.where(["active", "=", true]).count

          assert_requested :put, %r{sale\.sale/search_count} do |request|
            request_body = JSON.parse(request.body)

            assert_equal([["active", "=", true]], request_body["filters"])
          end
        end

        def test_runs_without_filtering_conditions_too
          stub_fulfil_request(:put, model: "sale.sale", suffix: "search_count", response: 10)

          @relation.count

          assert_requested :put, %r{sale\.sale/search_count} do |request|
            request_body = JSON.parse(request.body)

            assert_nil request_body["filters"]
          end
        end

        def test_repeating_counts_do_not_cause_extra_api_calls
          stub_fulfil_request(:put, model: "sale.sale", suffix: "search_count", response: 10)

          rand(2..10).times do
            @relation.count
          end

          assert_requested :put, %r{sale\.sale/search_count}, times: 1
        end

        def test_raises_model_name_missing_when_not_set
          assert_raises FulfilApi::Resource::ModelNameMissing do
            FulfilApi::Resource.count
          end
        end

        def test_raises_any_http_error_when_received
          stub_fulfil_request(:put, model: "sale.sale", suffix: "search_count", status: 500)

          assert_raises FulfilApi::Error do
            @relation.count
          end
        end

        def test_counting_indication
          stub_fulfil_request(:put, model: "sale.sale", suffix: "search_count", response: 10)

          refute_predicate @relation, :counted?

          @relation.count

          assert_predicate @relation, :counted?
        end

        def test_recounting_causes_a_new_http_request
          stub_fulfil_request(:put, model: "sale.sale", suffix: "search_count", response: 10)

          # We count three times, only one HTTP should be made
          assert_equal 10, @relation.count
          @relation.count
          @relation.count

          # Now, we recount and another HTTP request should be made
          stub_fulfil_request(:put, model: "sale.sale", suffix: "search_count", response: 15)

          assert_equal 15, @relation.recount

          assert_requested :put, %r{sale\.sale/search_count}, times: 2
        end
      end
    end
  end
end
