# frozen_string_literal: true

require "faraday"

module FulfilApi
  # The {FulfilApi::TplClient} allows making proxy requests to Fulfil's 3PL
  # carrier API endpoint. It provides a simple interface for interacting with
  # the 3PL supplier API using standard HTTP methods.
  #
  # @example Using the TPL client
  #   FulfilApi.tpl_client.get("shipments", page: 1)
  #   FulfilApi.tpl_client.post("shipments", { tracking_number: "123" })
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

    # Sends a DELETE request to the 3PL supplier API endpoint.
    #
    # @param path [String] The relative path to the endpoint.
    # @param body [Hash] The request body for the endpoint.
    # @return [Array, Hash] The JSON parsed response from the API endpoint.
    def delete(path, body: nil)
      request(:delete, path, body)
    end

    # Sends a GET request to the 3PL supplier API endpoint.
    #
    # @param path [String] The relative path to the endpoint.
    # @param query_params [Hash] The query parameters for the endpoint.
    # @return [Array, Hash] The JSON parsed response from the API endpoint.
    def get(path, query_params = {})
      connection.get(build_request_path(path), query_params.reject { |_key, value| value.blank? }).body
    rescue Faraday::Error => e
      handle_request_error(e)
    end

    # Sends a PATCH request to the 3PL supplier API endpoint.
    #
    # @param path [String] The relative path to the endpoint.
    # @param request_body [Hash] The request body for the endpoint.
    # @return [Array, Hash] The JSON parsed response from the API endpoint.
    def patch(path, request_body = {})
      request(:patch, path, request_body)
    end

    # Sends a POST request to the 3PL supplier API endpoint.
    #
    # @param path [String] The relative path to the endpoint.
    # @param request_body [Hash] The request body for the endpoint.
    # @return [Array, Hash] The JSON parsed response from the API endpoint.
    def post(path, request_body)
      request(:post, path, request_body)
    end

    # Sends a PUT request to the 3PL supplier API endpoint.
    #
    # @param path [String] The relative path to the endpoint.
    # @param request_body [Hash] The request body for the endpoint.
    # @return [Array, Hash] The JSON parsed response from the API endpoint.
    def put(path, request_body)
      request(:put, path, request_body)
    end

    private

    attr_reader :api_version, :auth_token, :configuration, :merchant_id

    # @return [String] The absolute URL to the API base URL.
    def api_endpoint
      @api_endpoint ||= "https://#{merchant_id}.fulfil.io"
    end

    # @param path [String] The relative path to the endpoint.
    # @return [String] The full, relative path to the endpoint.
    def build_request_path(path)
      "services/3pl/#{api_version}/#{path}".squeeze("/")
    end

    # @return [Faraday::Connection]
    def connection
      @connection ||= Faraday.new(
        headers: request_headers,
        url: api_endpoint,
        request: configuration.request_options
      ) do |connection|
        connection.adapter :net_http

        # Configuration of the request middleware
        connection.request :json

        # Configuration of the response middleware
        connection.response :json
        connection.response :raise_error
      end
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
    # @param path [String] The relative path to the endpoint.
    # @param body [Hash, Array, nil] The request body.
    # @return [Array, Hash, String] The parsed response body.
    def request(method, path, body = nil)
      if body
        connection.send(method.to_sym, build_request_path(path), body).body
      else
        connection.send(method.to_sym, build_request_path(path)).body
      end
    rescue Faraday::Error => e
      handle_request_error(e)
    end

    # @return [Hash<String, String>]
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
  #   FulfilApi.tpl_client.get("shipments")
  #   FulfilApi.tpl_client.post("shipments", { tracking_number: "123" })
  #
  # @return [FulfilApi::TplClient]
  def self.tpl_client
    TplClient.new(FulfilApi.configuration)
  end
end
