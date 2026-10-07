# frozen_string_literal: true

require "base64"
require "faraday"
require "securerandom"
require "uri"

module FulfilApi
  module OAuth
    # Drives Fulfil's OAuth 2.0 authorization flow for a single merchant
    #   workspace: it builds the URL the user is sent to, and exchanges the
    #   authorization code they come back with for an access token.
    #
    # @example
    #   authorization = FulfilApi::OAuth::Authorization.new(merchant_id: "acme")
    #   state = FulfilApi::OAuth::Authorization.generate_state
    #
    #   redirect_to authorization.url(state: state)
    #   # ... the user installs the app and returns with a `code` ...
    #   token = authorization.exchange(params[:code])
    #
    # @see https://docs.fulfil.io/developers/rest-api/authentication/oauth
    class Authorization
      AUTHORIZE_PATH = "/oauth/authorize"
      MERCHANT_ID_FORMAT = /\A[a-z0-9][a-z0-9-]*\z/
      TOKEN_PATH = "/oauth/token"

      attr_reader :access_type, :client_id, :merchant_id, :redirect_uri, :scopes

      # Fulfil requires a nonce that is unique per authorization request, so the
      #   callback can be verified to belong to the request that started it.
      #
      # @return [String]
      def self.generate_state
        SecureRandom.hex(24)
      end

      # Strips the parts of a Fulfil instance URL that surround the workspace ID.
      #   Unlike {.normalize_merchant_id} it accepts whatever it is given, which
      #   is what a database normalization needs to do.
      #
      # @param merchant_id [String, nil] The raw workspace ID.
      # @return [String]
      def self.normalize(merchant_id)
        merchant_id.to_s.strip.downcase
                   .delete_prefix("https://").delete_prefix("http://")
                   .delete_suffix("/")
                   .delete_suffix(".fulfil.io")
      end

      # Normalizes a merchant's workspace ID into the bare subdomain of their
      #   Fulfil instance, so `acme`, `acme.fulfil.io`, and
      #   `https://acme.fulfil.io` are all accepted.
      #
      # The workspace ID ends up in the host of the URL the user is redirected
      #   to, so anything that is not a bare subdomain is rejected rather than
      #   coerced into one.
      #
      # @param merchant_id [String, nil] The raw workspace ID.
      # @raise [FulfilApi::OAuth::MerchantIdInvalid] When the workspace ID is
      #   missing or is not a valid subdomain.
      # @return [String]
      def self.normalize_merchant_id(merchant_id)
        normalized = normalize(merchant_id)

        return normalized if MERCHANT_ID_FORMAT.match?(normalized)

        raise MerchantIdInvalid, "#{merchant_id.inspect} is not a valid Fulfil workspace ID."
      end

      # @param merchant_id [String, nil] The workspace ID of the merchant to
      #   install the app on. Defaults to the configured merchant.
      # @param redirect_uri [String, nil] The URL Fulfil redirects back to.
      #   Defaults to the configured redirect URI. It has to be whitelisted on
      #   the app in Fulfil's authentication dashboard.
      # @param configuration [FulfilApi::Configuration] The configuration to
      #   read the OAuth app's credentials from.
      def initialize(merchant_id: nil, redirect_uri: nil, configuration: FulfilApi.configuration)
        @configuration = configuration
        @oauth = configuration.oauth

        raise ConfigurationError, "Please configure the OAuth app's client ID and secret" unless @oauth.configured?

        @access_type = @oauth.access_type
        @client_id = @oauth.client_id
        @merchant_id = self.class.normalize_merchant_id(merchant_id.presence || configuration.merchant_id)
        @redirect_uri = redirect_uri.presence || @oauth.redirect_uri
        @scopes = @oauth.scopes
      end

      # Exchanges the authorization code from the callback for an access token.
      #
      # @param code [String] The authorization code Fulfil sent to the callback.
      # @raise [FulfilApi::OAuth::TokenExchangeFailed] When Fulfil rejected the code.
      # @return [FulfilApi::OAuth::Token]
      def exchange(code)
        raise TokenExchangeFailed, "No authorization code was provided" if code.blank?

        response = connection.post(TOKEN_PATH, { code: code }) do |request|
          request.params["grant_type"] = "authorization_code"
          request.headers["Authorization"] = "Basic #{basic_credentials}"
        end

        Token.new(response.body)
      rescue Faraday::Error => e
        raise TokenExchangeFailed.new(e.message, details: response_details(e))
      end

      # The URL of Fulfil's consent screen. Sending the user here is the first
      #   step of the flow.
      #
      # @param state [String] The nonce to verify the callback with.
      # @return [String]
      def url(state:)
        uri = URI.parse("#{api_endpoint}#{AUTHORIZE_PATH}")
        uri.query = URI.encode_www_form(url_parameters(state))
        uri.to_s
      end

      private

      attr_reader :configuration

      # @return [String]
      def api_endpoint
        "https://#{merchant_id}.fulfil.io"
      end

      # @return [String] The client's credentials as HTTP basic auth credentials.
      def basic_credentials
        Base64.strict_encode64("#{@oauth.client_id}:#{@oauth.client_secret}")
      end

      # The token endpoint lives outside of the versioned API namespace and
      #   expects a form encoded body, so it cannot reuse {FulfilApi::Client}.
      #
      # @return [Faraday::Connection]
      def connection
        Faraday.new(url: api_endpoint, request: configuration.request_options) do |connection|
          connection.request :url_encoded

          connection.response :json
          connection.response :raise_error
        end
      end

      # @param exception [Faraday::Error] The error raised while exchanging the code.
      # @return [Hash]
      def response_details(exception)
        {
          response_body: exception.response_body,
          response_headers: exception.response_headers,
          response_status: exception.response_status
        }
      end

      # @param state [String] The nonce to verify the callback with.
      # @return [Hash]
      def url_parameters(state)
        {
          access_type: access_type,
          client_id: client_id,
          redirect_uri: redirect_uri,
          response_type: "code",
          state: state
        }.tap do |parameters|
          parameters[:scope] = scopes.join(",") if scopes.any?
        end.compact
      end
    end
  end
end
