# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class ErrorsTest < Minitest::Test
      def setup
        @errors = Errors.new(FulfilApi::Resource.new(model_name: "sale.sale"))
      end

      def test_adding_an_error
        assert_equal 0, @errors.length

        @errors.add(code: "f123", type: :user, message: "already processed")

        assert_equal 1, @errors.length
      end

      def test_adding_an_error_returns_all
        errors = @errors.add(code: "f123", type: :user, message: "already processed")

        assert_equal [{ code: "f123", type: :user, message: "already processed" }], errors
      end

      def test_adding_a_duplicate_error
        assert_equal 0, @errors.length

        # Adds the same error multiple times
        @errors.add(code: "f123", type: :user, message: "already processed")
        @errors.add(code: "f123", type: :user, message: "already processed")
        @errors.add(code: "f123", type: :user, message: "already processed")

        # Adds a new error with another error code
        @errors.add(code: "f456", type: :user, message: "incorrect shipment status")

        assert_equal 2, @errors.length
      end

      def test_checking_existance_of_error
        refute @errors.added?(code: "f123", type: :user)

        @errors.add(code: "f123", type: :user, message: "already processed")

        assert @errors.added?(code: "f123", type: :user)
      end

      def test_clearing_previous_error_messages
        @errors.add(code: "f123", type: :user, message: "already processed")

        refute_empty @errors

        @errors.clear

        assert_empty @errors
      end

      def test_listing_error_messages
        assert_empty @errors.full_messages

        @errors.add(code: "f123", type: :user, message: "already processed")

        assert_equal ["already processed"], @errors.full_messages
      end

      def test_listing_errors
        assert_empty @errors.messages

        @errors.add(code: "f123", type: :user, message: "already processed")

        assert_equal [{ code: "f123", type: :user, message: "already processed" }], @errors.messages
      end
    end
  end
end
