# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class ErrorTest < Minitest::Test
    def test_expose_exception_details
      exception_details = { response_status: 404 }

      assert_equal(
        exception_details,
        FulfilApi::Error.new("something went wrong", details: exception_details).details
      )
    end

    def test_leaves_exception_details_empty_when_not_provided
      assert_nil FulfilApi::Error.new("something went wrong").details
    end

    def test_prefixes_the_exception_message
      assert_match(
        /\[FulfilApi::Error\]/i,
        FulfilApi::Error.new("something went wrong").message
      )
    end

    def test_prefixes_the_exception_message_with_the_specific_error
      assert_match(
        /\[FulfilApi::UnauthorizedError\]/i,
        FulfilApi::UnauthorizedError.new("something went wrong").message
      )
    end

    def test_from_response_builds_an_unauthorized_error_for_rejected_credentials
      error = FulfilApi::Error.from_response("nope", details: { response_status: 401 })

      assert_instance_of FulfilApi::UnauthorizedError, error
      assert_equal 401, error.details[:response_status]
    end

    def test_from_response_builds_a_generic_error_for_anything_else
      [403, 404, 422, 500, nil].each do |status|
        assert_instance_of(
          FulfilApi::Error,
          FulfilApi::Error.from_response("nope", details: { response_status: status })
        )
      end
    end
  end
end
