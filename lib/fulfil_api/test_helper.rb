# frozen_string_literal: true

require "webmock"

module FulfilApi
  # The TestHelper module provides utility methods for stubbing HTTP requests
  # to the Fulfil API in test environments. It uses WebMock to intercept and
  # simulate API requests, allowing developers to test how their code interacts
  # with the Fulfil API without making real HTTP requests.
  #
  # This module is designed to be included in test cases where you need to
  # simulate API interactions. It offers a flexible interface to stub requests
  # for various models and resources, making it easier to write comprehensive
  # and isolated tests.
  #
  # @example Including the TestHelper in your test case
  #   class MyTest < Minitest::Test
  #     include FulfilApi::TestHelper
  #
  #     def test_api_call
  #       stub_fulfil_request(:get, response: { name: "Product A" }, model: "product.product", id: "123")
  #       # Your test code here
  #     end
  #   end
  module TestHelper
    # Stubs an HTTP request to the Fulfil API based on the provided parameters.
    #
    # @param [String, Symbol] method The HTTP method to be stubbed (e.g., :get, :post).
    # @param [Hash] response The response body to return as a JSON object (default is {}).
    # @param [Integer] status The HTTP status code to return (default is 200).
    # @param [Hash] options Additional options, such as the model and ID for the request URL.
    # @option options [String] :model The API model (e.g., 'product.product', 'sale.sale').
    # @option options [String] :id The ID of the resource within the model (optional).
    #
    # @return [WebMock::RequestStub] The WebMock request stub object.
    #
    # @example Stub a GET request for a product model
    #   stub_fulfil_request(:get, response: { name: "Product A" }, model: "product.product", id: "123")
    def stub_fulfil_request(method, response: {}, status: 200, **options)
      stubbed_request_for(method, **options)
        .and_return(status: status, body: response.to_json, headers: { "Content-Type": "application/json" })
    end

    private

    # Builds the WebMock request stub for the Fulfil API based on the provided method and options.
    #
    # @param [String, Symbol] method The HTTP method to be stubbed (e.g., :get, :post).
    # @param [Hash] options Additional options, such as the model and ID for the request URL.
    # @option options [String] :model The API model (e.g., 'product.product', 'sale.sale').
    # @option options [String] :id The ID of the resource within the model (optional).
    #
    # @return [WebMock::RequestStub] The WebMock request stub object.
    #
    # @example Stub a POST request for creating a new order
    #   stubbed_request_for(:post, model: "sale.sale")
    #
    # @example Stub a GET request for a specific product
    #   stubbed_request_for(:get, model: "product.product", id: "123")
    def stubbed_request_for(method, **options)
      case options.transform_keys(&:to_sym)
      in { model:, id: }
        stub_request(method.to_sym, %r{fulfil.io/api/v\d+/(?:model/)?#{model}/#{id}(.*)}i)
      in { model: }
        stub_request(method.to_sym, %r{fulfil.io/api/v\d+/(?:model/)?#{model}(.*)}i)
      else
        stub_request(method.to_sym, %r{fulfil.io/api/v\d+}i)
      end
    end
  end
end
