# frozen_string_literal: true

require "faraday"
require "faraday/net_http_persistent"

module FulfilApi
  class Client
    # @param configuration [FulfilApi::Configuration]
    def initialize(configuration)
      @configuration = configuration
    end

    # Performs an HTTP DELETE request to a Fulfil API endpoint.
    #
    # @param relative_path [String] The relative path to the API resource.
    # @return [Array, Hash, String] The parsed response body.
    def delete(relative_path)
      request(:delete, relative_path)
    end

    # Performs an HTTP GET request to a Fulfil API endpoint.
    #
    # @param relative_path [String] The relative path to the API resource.
    # @param url_parameters [Hash, nil] The optional URL parameters for the API endpoint.
    # @return [Array, Hash, String] The parsed response body.
    def get(relative_path, url_parameters: nil)
      request(:get, relative_path, url_parameters)
    end

    # Performs an HTTP POST request to a Fulfil API endpoint.
    #
    # @param relative_path [String] The relative path to the API resource.
    # @param body [Array, Hash, nil] The request body for the POST HTTP request.
    # @return [Array, Hash, String] The parsed response body.
    def post(relative_path, body: {})
      request(:post, relative_path, body)
    end

    # Performs an HTTP PUT request to a Fulfil API endpoint.
    #
    # @param relative_path [String] The relative path to the API resource.
    # @param body [Array, Hash, nil] The optional request body for the PUT HTTP request.
    # @return [Array, Hash, String] The parsed response body.
    def put(relative_path, body: nil)
      return request(:put, relative_path) if body.nil?

      request(:put, relative_path, body)
    end

    private

    attr_reader :configuration

    # @return [String] The absolute URL to the API base URL.
    def api_endpoint
      @api_endpoint ||= "https://#{configuration.merchant_id}.fulfil.io"
    end

    # @return [Faraday::Connection]
    def connection
      # TODO: Allow passing configuration options for the request
      @connection ||= Faraday.new(url: api_endpoint) do |connection|
        connection.adapter :net_http_persistent # TODO: Allow passing configuration options

        # Configuration of the request middleware
        connection.request :json

        # Configuration of the response middleware
        connection.response :json
        connection.response :raise_error
      end
    end

    # @param relative_path [String] The relative path to the API endpoint.
    # @return [String] The absolute path for the request to the API endpoint.
    def expand_relative_path(relative_path)
      path = relative_path.start_with?("/") ? relative_path[1..] : relative_path
      "/api/#{configuration.api_version}/#{path}"
    end

    # @param exception [Faraday::Error] Any error raised by Faraday during the execution
    #   of the HTTP request to the API endpoint.
    def handle_request_error(exception)
      raise FulfilApi::Error.new(
        exception.message,
        details: {
          response_body: exception.response_body,
          response_headers: exception.response_headers,
          response_status: exception.response_status
        }
      )
    end

    # @param method [Symbol, String] The HTTP verb for the HTTP request.
    # @param relative_path [String] The relative path to the API endpoint.
    # @return [Array, Hash, String] The parsed response body.
    def request(method, relative_path, *args, **kwargs)
      connection.send(method.to_sym, expand_relative_path(relative_path), *args, **kwargs).body
    rescue Faraday::Error => e
      handle_request_error(e)
    end
  end

  # Builds an HTTP client to interact with an API endpoint of Fulfil.
  #
  # @example with a custom configuration
  #
  # To use a different configuration, wrap the call to the {.client} method into
  #   an {.with_config} block.
  #
  #   FulfilApi.with_config(...) do
  #     FulfilApi.client.get(...)
  #   end
  #
  # @return [FulfilApi::Client]
  def self.client
    Client.new(FulfilApi.configuration)
  end
end
