# frozen_string_literal: true

module FulfilApi
  module OAuth
    # Wraps the payload returned by Fulfil's `POST /oauth/token` endpoint.
    #
    # @example An `offline_access` payload
    #   {
    #     "access_token" => "user-xxxxx-xxxxxxx",
    #     "associated_user" => { "email" => "first.last@example.com", "id" => 1, "name" => "First Last" },
    #     "expires_in" => 3600,
    #     "offline_access_token" => "bot-xxxx",
    #     "scope" => ["user_session,party.party"],
    #     "token_type" => "Bearer"
    #   }
    class Token
      DEFAULT_TOKEN_TYPE = "Bearer"

      attr_reader :access_token, :associated_user, :expires_in, :offline_access_token, :scopes, :token_type

      # @param payload [Hash] The parsed response body of the token endpoint.
      def initialize(payload)
        payload = (payload || {}).with_indifferent_access

        @access_token = payload[:access_token].presence
        @associated_user = (payload[:associated_user] || {}).with_indifferent_access
        @expires_in = payload[:expires_in]&.to_i
        @offline_access_token = payload[:offline_access_token].presence
        @scopes = extract_scopes(payload[:scope])
        @token_type = payload[:token_type].presence || DEFAULT_TOKEN_TYPE
      end

      # The moment the short-lived {#access_token} stops working. The
      #   {#offline_access_token} is not covered by this: it stays valid until
      #   the app is uninstalled from the workspace.
      #
      # @return [Time, nil]
      def expires_at
        return if expires_in.nil?

        Time.now.utc + expires_in
      end

      # @return [true, false] Whether a permanent token was granted.
      def offline?
        offline_access_token.present?
      end

      # Prefers the permanent token over the short-lived one, so a token used
      #   outside of the request it was granted in keeps working.
      #
      # @return [FulfilApi::AccessToken]
      def to_access_token
        FulfilApi::AccessToken.new(value, type: :oauth)
      end

      # @return [String, nil] The token to authenticate API requests with.
      def value
        offline_access_token || access_token
      end

      private

      # Fulfil returns the granted scopes as an array holding a single comma
      #   separated string (`["user_session,party.party"]`) rather than as a
      #   list of scopes, so both shapes are flattened into a plain list.
      #
      # @param scope [Array<String>, String, nil] The granted scopes.
      # @return [Array<String>]
      def extract_scopes(scope)
        Array(scope).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:empty?).uniq
      end
    end
  end
end
