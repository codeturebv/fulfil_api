# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class Resource
    class PersistableTest < Minitest::Test
      def setup
        @attributes = { id: rand(777), state: "processing" }
        @resource = Resource.new(model_name: "sale.sale", **@attributes)
        @user_error = { "type" => "UserError", "code" => "f123", "message" => "can't update sales order in this state" }
      end

      def test_updating_resource_klass_requires_id_and_model_name
        assert_raises FulfilApi::Error do
          FulfilApi::Resource.update(id: nil, model_name: nil, state: "done")
        end

        assert_raises FulfilApi::Error do
          FulfilApi::Resource.update!(id: nil, model_name: nil, state: "done")
        end
      end

      def test_updating_resource_changes_attributes
        stub_fulfil_request(:put, response: @attributes.merge(state: "done"))

        @resource.update(state: "done")

        assert_equal @attributes.merge(state: "done").deep_stringify_keys, @resource.to_h
      end

      def test_failure_of_updating_resource_changes_attributes
        stub_fulfil_request(:put, response: @user_error, status: 423)

        @resource.update(state: "done")

        assert_equal @attributes.merge(state: "done").deep_stringify_keys, @resource.to_h
      end

      def test_saving_resource_without_id
        skip "the #create method(s) have not been implemented yet"
      end

      def test_saving_resource_with_id
        stub_fulfil_request(:put, response: @attributes)

        @resource.save

        assert_requested :put, /fulfil\.io/
      end

      def test_saving_resource_with_updated_attributes
        stub_fulfil_request(:put, response: @attributes)

        @resource.assign_attributes(state: "done")
        @resource.save

        assert_requested :put, /fulfil\.io/ do |request|
          assert_equal @attributes.merge(state: "done").deep_stringify_keys, JSON.parse(request.body)
        end
      end

      def test_saving_an_invalid_resource_with_bang
        stub_fulfil_request(:put, response: @user_error, status: 423)

        @resource.assign_attributes({ state: "done" })

        assert_raises FulfilApi::Error do
          @resource.save!
        end
      end

      def test_saving_an_invalid_resource_without_bang
        stub_fulfil_request(:put, response: @user_error, status: 423)

        @resource.assign_attributes({ state: "done" })
        @resource.save

        refute_empty @resource.errors
        assert_equal [@user_error["message"]], @resource.errors.full_messages
      end

      def test_saving_resource_clears_previous_errors
        stub_fulfil_request(:put, response: @attributes.merge(state: "done"))

        # Add an error to the resource
        @resource.errors.add(code: "f123", type: :user, message: "already processed")

        # Calling {#save} will clear the previous errors
        @resource.assign_attributes({ state: "done" })
        @resource.save

        assert_empty @resource.errors
      end
    end
  end
end
