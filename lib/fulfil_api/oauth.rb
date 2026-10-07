# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::OAuth} namespace contains everything needed to obtain an
  #   access token through Fulfil's OAuth 2.0 authorization flow.
  #
  # Fulfil's flow has two access modes. The `user_session` mode returns a
  #   short-lived token tied to the user's web session, while the
  #   `offline_access` mode additionally returns an `offline_access_token` that
  #   remains valid until the app is uninstalled. There is no refresh token in
  #   either mode: an expired `user_session` token can only be replaced by
  #   sending the user through the flow again.
  #
  # @see https://docs.fulfil.io/developers/rest-api/authentication/oauth
  module OAuth
    class Error < FulfilApi::Error; end

    # Raised when the flow is started without a client ID or secret.
    class ConfigurationError < Error; end

    # Raised when the merchant's workspace ID is missing or malformed. The
    #   workspace ID ends up in the host of the URL the user is redirected to,
    #   so an unchecked value would allow redirecting to an arbitrary host.
    class MerchantIdInvalid < Error; end

    # Raised when the user cancelled the installation, or when Fulfil reported
    #   an error on the callback.
    class AuthorizationDenied < Error; end

    # Raised when the `state` on the callback does not match the one generated
    #   when the flow was started, which means the callback cannot be trusted.
    class StateMismatch < Error; end

    # Raised when exchanging the authorization code for an access token failed.
    class TokenExchangeFailed < Error; end
  end
end
