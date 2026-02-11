# frozen_string_literal: true

require "faraday"
require "faraday/net_http_persistent"

module FulfilApi
  # The {FulfilApi::TplClient} allows making proxy requests to Fulfil's 3PL
  # carrier API endpoint. It provides a simple interface for interacting with
  # the 3PL supplier API using standard HTTP methods.
  #
  # @example Using the TPL client
  #   FulfilApi.tpl_client.get("inbound-transfers", page: 1)
  #   FulfilApi.tpl_client.post("inbound-transfers/receive.json", { tracking_number: "123" })
  class TplClient
    class ConfigurationError < FulfilApi::Error; end

    DEFAULT_API_VERSION = "v1"

    # @param configuration [FulfilApi::Configuration]
    def initialize(configuration)
      @configuration = configuration

      tpl_config = configuration.tpl || {}

      @auth_token = tpl_config[:auth_token].presence ||
                    raise(ConfigurationError,
                          "Please provide a 3PL authentication token via config.tpl = { auth_token: ... }")
      @merchant_id = tpl_config[:merchant_id].presence || configuration.merchant_id.presence ||
                     raise(ConfigurationError, "Please provide a merchant ID")
      @api_version = tpl_config[:api_version].presence || DEFAULT_API_VERSION
    end

    # Performs an HTTP GET request to a 3PL API endpoint.
    #
    # @param relative_path [String] The relative path to the endpoint.
    # @param url_parameters [Hash] The optional URL parameters for the API endpoint.
    # @return [Array, Hash, String] The parsed response body.
    def get(relative_path, **url_parameters)
      request(:get, relative_path, url_parameters.presence)
    end

    # Performs an HTTP PATCH request to a 3PL API endpoint.
    #
    # @param relative_path [String] The relative path to the endpoint.
    # @param body [Array, Hash, nil] The request body for the PATCH HTTP request.
    # @return [Array, Hash, String] The parsed response body.
    def patch(relative_path, body = {})
      request(:patch, relative_path, body)
    end

    # Performs an HTTP POST request to a 3PL API endpoint.
    #
    # @param relative_path [String] The relative path to the endpoint.
    # @param body [Array, Hash, nil] The request body for the POST HTTP request.
    # @return [Array, Hash, String] The parsed response body.
    def post(relative_path, body = {})
      request(:post, relative_path, body)
    end

    # Performs an HTTP PUT request to a 3PL API endpoint.
    #
    # @param relative_path [String] The relative path to the endpoint.
    # @param body [Array, Hash, nil] The optional request body for the PUT HTTP request.
    # @return [Array, Hash, String] The parsed response body.
    def put(relative_path, body = nil)
      return request(:put, relative_path) if body.nil?

      request(:put, relative_path, body)
    end

    private

    attr_reader :api_version, :auth_token, :configuration, :merchant_id

    # @return [String] The absolute URL to the API base URL.
    def api_endpoint
      @api_endpoint ||= "https://#{merchant_id}.fulfil.io"
    end

    # @return [Faraday::Connection]
    def connection
      @connection ||= Faraday.new(
        headers: request_headers,
        url: api_endpoint,
        request: configuration.request_options
      ) do |connection|
        connection.adapter :net_http_persistent

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
      "/services/3pl/#{api_version}/#{path}"
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

    # @return [Hash] The HTTP headers for any HTTP request to the 3PL API.
    def request_headers
      {
        "Authorization" => "Bearer #{auth_token}",
        "Content-Type" => "application/json"
      }
    end
  end

  # Builds an HTTP client to interact with Fulfil's 3PL API endpoint.
  #
  # @example
  #   FulfilApi.tpl_client.get("inbound-transfers")
  #   FulfilApi.tpl_client.post("inbound-transfers/receive.json", { tracking_number: "123" })
  #
  # @return [FulfilApi::TplClient]
  def self.tpl_client
    TplClient.new(FulfilApi.configuration)
  end
end
