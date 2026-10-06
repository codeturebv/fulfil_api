# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class DeadlineTest < Minitest::Test
    def setup
      @merchant_id = "merchant-#{SecureRandom.uuid}"
      @client = FulfilApi::Client.new(FulfilApi::Configuration.new(merchant_id: @merchant_id))
    end

    def test_runs_without_a_deadline_by_default
      FulfilApi.with_deadline do
        assert_nil FulfilApi::Deadline.current
      end
    end

    def test_sets_the_deadline_for_the_duration_of_the_block
      FulfilApi.with_deadline(5) do
        assert_in_delta 5, FulfilApi::Deadline.current.remaining, 0.1
      end

      assert_nil FulfilApi::Deadline.current
    end

    def test_uses_the_configured_deadline_as_the_default
      FulfilApi.with_config(deadline: 2) do
        FulfilApi.with_deadline do
          assert_in_delta 2, FulfilApi::Deadline.current.remaining, 0.1
        end
      end
    end

    def test_restores_the_previous_deadline_when_the_block_raises
      assert_raises(RuntimeError) do
        FulfilApi.with_deadline(5) { raise "boom" }
      end

      assert_nil FulfilApi::Deadline.current
    end

    def test_a_nested_deadline_can_shorten_the_outer_deadline
      FulfilApi.with_deadline(5) do
        FulfilApi.with_deadline(1) do
          assert_in_delta 1, FulfilApi::Deadline.current.remaining, 0.1
        end

        assert_in_delta 5, FulfilApi::Deadline.current.remaining, 0.1
      end
    end

    def test_a_nested_deadline_cannot_extend_the_outer_deadline
      FulfilApi.with_deadline(1) do
        FulfilApi.with_deadline(5) do
          assert_in_delta 1, FulfilApi::Deadline.current.remaining, 0.1
        end
      end
    end

    def test_sends_requests_within_the_deadline
      stub_fulfil_request(:get, model: "sale.sale", id: 123)

      FulfilApi.with_deadline(5) { @client.get("sale.sale/123") }

      assert_requested :get, %r{sale\.sale/123}, times: 1
    end

    def test_does_not_send_requests_after_the_deadline_ran_out
      stub_fulfil_request(:get, model: "sale.sale", id: 123)

      error =
        assert_raises(FulfilApi::Deadline::Exceeded) do
          FulfilApi.with_deadline(0) { @client.get("sale.sale/123") }
        end

      assert_kind_of FulfilApi::Error, error
      assert_empty error.details
      assert_not_requested :get, %r{sale\.sale/123}
    end

    def test_does_not_retry_after_the_deadline_ran_out
      stubbed_request_for(:put, model: "sale.sale", suffix: "search_read")
        .to_return(lambda { |_request|
          sleep 0.06
          raise Errno::ECONNRESET
        })

      assert_raises(FulfilApi::HttpError) do
        FulfilApi.with_deadline(0.05) { @client.put("/model/sale.sale/search_read", body: { filters: [] }) }
      end
      assert_requested :put, %r{sale\.sale/search_read}, times: 1
    end
  end
end
