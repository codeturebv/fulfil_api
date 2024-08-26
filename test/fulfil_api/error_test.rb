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
  end
end
