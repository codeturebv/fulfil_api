# frozen_string_literal: true

module FulfilApi
  # Walks a user through Fulfil's OAuth 2.0 authorization flow.
  #
  # `GET /installation/new` sends the user to Fulfil's consent screen, and
  #   `GET /callback` turns the authorization code they return with into an
  #   {FulfilApi::Installation}. The callback URL is the one that has to be
  #   whitelisted on the app in Fulfil's authentication dashboard.
  class InstallationsController < FulfilApi::ApplicationController
    MERCHANT_ID_SESSION_KEY = "fulfil_api.oauth.merchant_id"
    RETURN_TO_SESSION_KEY = "fulfil_api.oauth.return_to"
    STATE_SESSION_KEY = "fulfil_api.oauth.state"

    # Handles the callback of the authorization flow.
    #
    # @raise [FulfilApi::OAuth::AuthorizationDenied] When the user cancelled the installation.
    # @raise [FulfilApi::OAuth::StateMismatch] When the callback cannot be tied
    #   to the authorization request that started it.
    # @return [void]
    def create
      merchant_id = session.delete(MERCHANT_ID_SESSION_KEY)
      return_to = session.delete(RETURN_TO_SESSION_KEY)
      verify_state!

      authorization = authorization_for(merchant_id)
      installation = FulfilApi::Installation.install(
        authorization.exchange(params[:code]),
        merchant_id: authorization.merchant_id,
        owner: fulfil_installation_owner
      )

      redirect_to return_to.presence || after_install_path(installation), allow_other_host: false
    end

    # Kicks off the authorization flow by sending the user to Fulfil.
    #
    # @return [void]
    def new
      authorization = authorization_for(params[:merchant_id])
      remember_authorization_request(authorization)

      redirect_to authorization.url(state: session[STATE_SESSION_KEY]), allow_other_host: true
    end

    private

    # @param installation [FulfilApi::Installation] The installation that was just created.
    # @return [String]
    def after_install_path(installation)
      path = FulfilApi.configuration.oauth.after_install_path
      path.respond_to?(:call) ? path.call(installation) : path
    end

    # Fulfil does not send the workspace back to the callback, so the one the
    #   flow started on is kept in the session. Without it, a workspace the user
    #   picked when starting the flow would be lost, and the code exchanged on
    #   whatever {#fulfil_merchant_id} returns instead.
    #
    # @param merchant_id [String, nil] The workspace to install the app on.
    #   Defaults to the workspace of the current request.
    # @return [FulfilApi::OAuth::Authorization]
    def authorization_for(merchant_id)
      FulfilApi::OAuth::Authorization.new(
        merchant_id: merchant_id.presence || fulfil_merchant_id,
        redirect_uri: FulfilApi.configuration.oauth.redirect_uri.presence || callback_url
      )
    end

    # Only paths within the application are remembered, so the `return_to`
    #   parameter cannot be used to bounce a user off to another host.
    #
    # @return [true, false]
    def internal_return_to?
      params[:return_to].present? && params[:return_to].to_s.start_with?("/") &&
        !params[:return_to].to_s.start_with?("//")
    end

    # Keeps what the callback needs to finish the flow: the nonce to verify,
    #   the workspace to exchange the code on, and where to send the user after.
    #
    # @param authorization [FulfilApi::OAuth::Authorization] The authorization being requested.
    # @return [void]
    def remember_authorization_request(authorization)
      session[MERCHANT_ID_SESSION_KEY] = authorization.merchant_id
      session[STATE_SESSION_KEY] = FulfilApi::OAuth::Authorization.generate_state
      session[RETURN_TO_SESSION_KEY] = params[:return_to] if internal_return_to?
    end

    # @raise [FulfilApi::OAuth::AuthorizationDenied]
    # @return [void]
    def verify_authorization!
      return if params[:error].blank?

      raise FulfilApi::OAuth::AuthorizationDenied,
            "Fulfil denied the authorization request: #{params[:error_description].presence || params[:error]}"
    end

    # @raise [FulfilApi::OAuth::AuthorizationDenied]
    # @raise [FulfilApi::OAuth::StateMismatch]
    # @return [void]
    def verify_state!
      state = session.delete(STATE_SESSION_KEY)
      verify_authorization!

      return if state.present? && ActiveSupport::SecurityUtils.secure_compare(state, params[:state].to_s)

      raise FulfilApi::OAuth::StateMismatch, "The state of the callback does not match the authorization request"
    end
  end
end
