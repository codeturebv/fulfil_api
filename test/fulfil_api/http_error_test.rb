# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class HttpErrorTest < Minitest::Test
    TOO_MANY_REQUESTS = {
      code: 429,
      name: "Too Many Requests",
      description: "This user has exceeded an allotted request count. Try again later."
    }.freeze

    def test_dedicated_error_class_for_every_known_status_code
      FulfilApi::HttpError::STATUS_CODES.each_key do |status_code|
        assert_operator FulfilApi::HttpError.for_status_code(status_code), :<, FulfilApi::HttpError
      end
    end

    def test_lookup_of_the_error_class_for_a_status_code
      assert_equal FulfilApi::HttpError::TooManyRequests, FulfilApi::HttpError.for_status_code(429)
    end

    def test_fallback_to_the_generic_error_for_an_unknown_status_code
      assert_equal FulfilApi::HttpError, FulfilApi::HttpError.for_status_code(499)
    end

    def test_fallback_to_the_generic_error_without_a_status_code
      assert_equal FulfilApi::HttpError, FulfilApi::HttpError.for_status_code(nil)
    end

    def test_rescuable_as_a_generic_error
      assert_kind_of FulfilApi::Error, FulfilApi::HttpError::TooManyRequests.new("try again later")
    end

    def test_leaves_the_exception_message_unprefixed
      assert_equal "try again later", FulfilApi::HttpError::TooManyRequests.new("try again later").message
    end

    def test_building_the_error_for_the_status_code_of_the_response
      exception = FulfilApi::HttpError.from_faraday_error(faraday_error(429, TOO_MANY_REQUESTS))

      assert_instance_of FulfilApi::HttpError::TooManyRequests, exception
    end

    def test_building_the_message_from_the_description_of_the_response
      exception = FulfilApi::HttpError.from_faraday_error(faraday_error(429, TOO_MANY_REQUESTS))

      assert_equal TOO_MANY_REQUESTS[:description], exception.message
    end

    def test_building_the_message_from_the_message_of_the_response
      body = { type: "UserError", code: "E1000", message: "can't update sales order in this state" }
      exception = FulfilApi::HttpError.from_faraday_error(faraday_error(422, body))

      assert_equal "can't update sales order in this state", exception.message
    end

    def test_building_the_message_from_the_error_of_the_response
      exception = FulfilApi::HttpError.from_faraday_error(faraday_error(422, { error: "something went wrong" }))

      assert_equal "something went wrong", exception.message
    end

    def test_ignoring_a_non_textual_message_in_the_response
      faraday_exception = faraday_error(422, { message: { nested: "hash" } })
      exception = FulfilApi::HttpError.from_faraday_error(faraday_exception)

      assert_equal faraday_exception.message, exception.message
    end

    def test_fallback_to_the_faraday_message_for_a_non_json_response_body
      faraday_exception = faraday_error(502, "<html>Bad Gateway</html>")
      exception = FulfilApi::HttpError.from_faraday_error(faraday_exception)

      assert_equal faraday_exception.message, exception.message
    end

    def test_fallback_to_the_faraday_message_for_an_empty_response_body
      faraday_exception = faraday_error(503, "")
      exception = FulfilApi::HttpError.from_faraday_error(faraday_exception)

      assert_equal faraday_exception.message, exception.message
    end

    def test_generic_error_for_a_request_that_never_reached_fulfil
      exception = FulfilApi::HttpError.from_faraday_error(Faraday::ConnectionFailed.new("Connection reset by peer"))

      assert_instance_of FulfilApi::HttpError, exception
    end

    def test_exposure_of_the_status_code
      exception = FulfilApi::HttpError.from_faraday_error(faraday_error(429, TOO_MANY_REQUESTS))

      assert_equal 429, exception.status_code
    end

    def test_exposure_of_the_response_body
      exception = FulfilApi::HttpError.from_faraday_error(faraday_error(429, TOO_MANY_REQUESTS))

      assert_equal TOO_MANY_REQUESTS.to_json, exception.response_body
    end

    def test_exposure_of_the_response_headers
      exception = FulfilApi::HttpError.from_faraday_error(faraday_error(429, TOO_MANY_REQUESTS))

      assert_equal({ "content-type" => "application/json" }, exception.response_headers)
    end

    def test_exposure_of_the_exception_details
      exception = FulfilApi::HttpError.from_faraday_error(faraday_error(429, TOO_MANY_REQUESTS))

      assert_equal 429, exception.details[:response_status]
    end

    private

    # @param status_code [Integer] The HTTP status code of the response.
    # @param body [Hash, String] The response body of the API endpoint.
    # @return [Faraday::Error] The exception Faraday raises for a failed request.
    def faraday_error(status_code, body)
      Faraday::Error.new({
                           status: status_code,
                           headers: { "content-type" => "application/json" },
                           body: body.is_a?(String) ? body : body.to_json
                         })
    end
  end
end
