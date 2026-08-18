# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Error
    class NotifiableTest < Minitest::Test
      def test_publishing_an_event_when_raising_an_error_class
        events = capture_error_events do
          assert_raises(FulfilApi::Error) { raise FulfilApi::Error, "something went wrong" }
        end

        assert_equal 1, events.size
        assert_equal "[FulfilApi::Error] something went wrong", events.first.payload[:exception_object].message
      end

      def test_publishing_an_event_when_raising_an_error_instance
        events = capture_error_events do
          # rubocop:disable Style/RaiseArgs -- raising an instance is the form under test
          assert_raises(FulfilApi::Error) { raise FulfilApi::Error.new("something went wrong") }
          # rubocop:enable Style/RaiseArgs
        end

        assert_equal 1, events.size
      end

      def test_publishing_an_event_for_every_descendant_of_the_base_error
        events = capture_error_events do
          assert_raises(FulfilApi::Resource::ModelNameMissing) { raise FulfilApi::Resource::ModelNameMissing }
        end

        assert_instance_of FulfilApi::Resource::ModelNameMissing, events.first.payload[:exception_object]
      end

      def test_publishing_nothing_when_an_error_is_built_but_never_raised
        events = capture_error_events do
          FulfilApi::HttpError::TooManyRequests.new("slow down")
        end

        assert_empty events
      end

      def test_publishing_the_exception_in_the_payload_of_the_event
        events = capture_error_events do
          assert_raises(FulfilApi::Error) { raise FulfilApi::Error, "something went wrong" }
        end

        assert_equal ["FulfilApi::Error", "[FulfilApi::Error] something went wrong"], events.first.payload[:exception]
      end

      def test_publishing_the_response_of_fulfil_for_an_http_error
        events = capture_error_events do
          assert_raises(FulfilApi::HttpError::TooManyRequests) do
            raise FulfilApi::HttpError.from_faraday_error(too_many_requests_error)
          end
        end

        payload = events.first.payload

        assert_equal 429, payload[:status_code]
        assert_equal({ "retry-after" => "5" }, payload[:response_headers])
        assert_equal({ "description" => "slow down" }, payload[:response_body])
      end

      def test_publishing_an_event_for_a_failed_request_to_fulfil
        stub_fulfil_request(:put, model: "sale.sale", status: 429, response: { description: "slow down" })

        events = capture_error_events do
          assert_raises(FulfilApi::HttpError::TooManyRequests) do
            FulfilApi::Resource.set(model_name: "sale.sale").find_by(["id", "=", 100])
          end
        end

        assert_equal 429, events.first.payload[:status_code]
      end

      def test_yielding_the_raised_error_to_a_subscriber_of_on_error
        errors = []
        subscriber = FulfilApi.on_error { |error| errors << error }

        assert_raises(FulfilApi::Error) { raise FulfilApi::Error, "something went wrong" }

        assert_instance_of FulfilApi::Error, errors.first
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      def test_keeping_a_raised_error_rescuable_when_a_subscriber_raises
        subscriber = FulfilApi.on_error { raise "the APM is unreachable" }

        error = assert_raises(FulfilApi::HttpError::TooManyRequests) do
          silence_warnings { raise FulfilApi::HttpError::TooManyRequests, "slow down" }
        end

        assert_equal "slow down", error.message
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      def test_publishing_no_event_for_an_error_raised_by_a_subscriber
        invocations = 0
        subscriber = FulfilApi.on_error do
          invocations += 1
          begin
            raise FulfilApi::Error, "raised from within the subscriber"
          rescue FulfilApi::Error
            nil
          end
        end

        assert_raises(FulfilApi::Error) { raise FulfilApi::Error, "something went wrong" }

        assert_equal 1, invocations
        assert_nil Thread.current[FulfilApi::Error::REENTRANCY_KEY]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      private

      # Collects every {FulfilApi::Error::EVENT_NAME} event published while the block
      #   runs, and unsubscribes again afterwards.
      #
      # @return [Array<ActiveSupport::Notifications::Event>]
      def capture_error_events(&block)
        events = []
        collect = ->(event) { events << event }

        ActiveSupport::Notifications.subscribed(collect, FulfilApi::Error::EVENT_NAME, &block)

        events
      end

      # @return [Faraday::TooManyRequestsError]
      def too_many_requests_error
        Faraday::TooManyRequestsError.new(
          nil,
          {
            body: { "description" => "slow down" },
            headers: { "retry-after" => "5" },
            status: 429
          }
        )
      end

      # Keeps the warning of a raising subscriber out of the output of the test suite.
      def silence_warnings
        original = $stderr
        $stderr = StringIO.new
        yield
      ensure
        $stderr = original
      end
    end
  end
end
