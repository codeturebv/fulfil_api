# frozen_string_literal: true

module FulfilApi
  # An {FulfilApi::Installation} records that the OAuth app was installed on a
  #   merchant's Fulfil workspace, and holds the access token that came out of
  #   it.
  #
  # An installation without an owner is the application-wide installation, which
  #   is what a Rails application built for a single merchant needs. Assigning an
  #   owner scopes the installation to a record instead, which is what an
  #   application serving many merchants needs — see {FulfilApi::Installable}.
  class Installation < ActiveRecord::Base
    belongs_to :owner, polymorphic: true, optional: true

    encrypts :access_token
    encrypts :offline_access_token

    normalizes :merchant_id, with: ->(merchant_id) { FulfilApi::OAuth::Authorization.normalize(merchant_id) }

    validates :merchant_id, presence: true, uniqueness: { scope: %i[owner_type owner_id] }

    scope :global, -> { where(owner: nil) }

    serialize :scopes, coder: JSON, type: Array

    # Records the outcome of a completed authorization flow, replacing the
    #   tokens of an earlier installation on the same workspace.
    #
    # @param token [FulfilApi::OAuth::Token] The granted access token.
    # @param merchant_id [String] The workspace the app was installed on.
    # @param owner [ActiveRecord::Base, nil] The record the installation belongs
    #   to, or `nil` for the application-wide installation.
    # @return [FulfilApi::Installation]
    def self.install(token, merchant_id:, owner: nil)
      installation = find_or_initialize_by(owner: owner, merchant_id: merchant_id)
      installation.assign_token(token)
      installation.save!
      installation
    end

    # Looks up the installation to authenticate a Fulfil API request with.
    #
    # @param owner [ActiveRecord::Base, nil] The record the installation belongs to.
    # @param merchant_id [String, nil] The workspace to find the installation for.
    # @return [FulfilApi::Installation, nil]
    def self.installed_on(merchant_id: FulfilApi.configuration.merchant_id, owner: nil)
      return if merchant_id.blank?

      find_by(owner: owner, merchant_id: merchant_id)
    end

    # Copies the granted token onto the installation.
    #
    # Re-authorizing in `user_session` mode does not return an
    #   `offline_access_token`, so an already granted permanent token is kept
    #   rather than wiped.
    #
    # @param token [FulfilApi::OAuth::Token] The granted access token.
    # @return [void]
    def assign_token(token)
      assign_attributes(
        access_token: token.access_token,
        expires_at: token.expires_at,
        scopes: token.scopes,
        token_type: token.token_type
      )

      assign_associated_user(token.associated_user)
      self.offline_access_token = token.offline_access_token if token.offline?
    end

    # Whether the short-lived token has passed its expiry. It says nothing about
    #   the permanent token, which is only revoked by uninstalling the app.
    #
    # @return [true, false]
    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    # @return [true, false] Whether a permanent token was granted.
    def offline?
      offline_access_token.present?
    end

    # @return [FulfilApi::AccessToken]
    def to_access_token
      FulfilApi::AccessToken.new(offline_access_token.presence || access_token, type: :oauth)
    end

    # Whether the installation can still authenticate requests, or whether the
    #   user has to walk through the authorization flow again.
    #
    # @return [true, false]
    def usable?
      return true if offline?

      access_token.present? && !expired?
    end

    # Runs a block against the Fulfil API as this installation.
    #
    # @example
    #   installation.with_config do |client|
    #     client.get("model/sale.sale")
    #   end
    #
    # @yieldparam [FulfilApi::Client] client A client authenticated as this installation.
    # @return [void]
    def with_config
      FulfilApi.with_config(access_token: to_access_token, merchant_id: merchant_id) do
        yield(FulfilApi.client)
      end
    end

    private

    # @param user [Hash] The user who walked through the authorization flow.
    # @return [void]
    def assign_associated_user(user)
      assign_attributes(
        associated_user_email: user[:email],
        associated_user_id: user[:id],
        associated_user_name: user[:name]
      )
    end
  end
end
