# frozen_string_literal: true

FulfilApi.configure do |config|
  # The subdomain of the Fulfil workspace this application talks to. Leave it
  #   blank when every tenant brings its own workspace, and override
  #   `fulfil_merchant_id` in ApplicationController instead.
  config.merchant_id = ENV.fetch("FULFIL_MERCHANT_ID", nil)

  # The credentials of the app registered on https://auth.fulfil.io/user/clients.
  config.oauth.client_id = ENV.fetch("FULFIL_OAUTH_CLIENT_ID", nil)
  config.oauth.client_secret = ENV.fetch("FULFIL_OAUTH_CLIENT_SECRET", nil)

  # The scopes to request. See https://developers.fulfil.io for the full list.
  config.oauth.scopes = []

  # `:offline_access` grants a permanent token that keeps working when no user
  #   is around, which is what background jobs need. `:user_session` grants a
  #   token that expires with the user's Fulfil session.
  config.oauth.access_type = :offline_access

  # Where the user ends up after installing the app, unless they were sent to
  #   the flow from somewhere else. Accepts a path or a callable taking the
  #   FulfilApi::Installation that was created.
  config.oauth.after_install_path = "/"

  # REQUIRED before the OAuth flow can be used. The engine's controllers inherit
  #   from this one, so it has to be a controller that authenticates the request
  #   and — in an application serving many merchants — establishes the current
  #   tenant. There is deliberately no default: an unauthenticated flow lets a
  #   stranger record their own Fulfil workspace over yours, and a flow outside
  #   the application's tenancy records installations against the wrong owner.
  #
  # config.oauth.parent_controller = "AuthenticatedController"

  # Fulfil requires the redirect URL to be whitelisted on the app. It defaults
  #   to the engine's callback URL, which is derived from the incoming request.
  # config.oauth.redirect_uri = "https://example.com/fulfil/callback"
end
