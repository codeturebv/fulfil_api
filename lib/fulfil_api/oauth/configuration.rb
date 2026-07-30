# frozen_string_literal: true

module FulfilApi
  module OAuth
    # Holds the credentials and options of the OAuth app that was registered in
    #   Fulfil's authentication dashboard, plus the Rails-specific settings used
    #   by {FulfilApi::Engine}.
    #
    # @see https://auth.fulfil.io/user/clients
    class Configuration
      ACCESS_TYPES = %i[offline_access user_session].freeze

      # Fulfil's own default is `user_session`, but the gem defaults to
      #   `offline_access`. An app that talks to Fulfil from background jobs
      #   needs a token that outlives the user's web session, and personal
      #   access tokens are no longer a viable alternative now that they expire.
      DEFAULT_ACCESS_TYPE = :offline_access
      DEFAULT_AFTER_INSTALL_PATH = "/"
      DEFAULT_MOUNT_PATH = "/fulfil"
      DEFAULT_PARENT_CONTROLLER = "ApplicationController"
      DEFAULT_SCOPES = [].freeze

      attr_accessor :after_install_path, :client_id, :client_secret, :parent_controller, :redirect_uri
      attr_reader :access_type, :scopes

      # @param options [Hash, nil] An optional list of configuration options.
      def initialize(options = {})
        (options || {}).each_pair do |key, value|
          public_send(:"#{key}=", value) if respond_to?(:"#{key}=")
        end

        set_default_options
      end

      # @param value [Symbol, String] Either `:offline_access` or `:user_session`.
      # @raise [ArgumentError] When the access type is not supported by Fulfil.
      # @return [void]
      def access_type=(value)
        @access_type = value.to_sym

        return if ACCESS_TYPES.include?(@access_type)

        raise ArgumentError, "#{value} is not a valid access type. Use :offline_access or :user_session instead."
      end

      # @return [true, false] Whether an access token can be requested at all.
      def configured?
        client_id.present? && client_secret.present?
      end

      # @return [true, false] Whether a permanent, user-independent token is requested.
      def offline_access?
        access_type == :offline_access
      end

      # @param value [Array<String>, String, nil] A list of scopes, or a comma
      #   separated string of scopes.
      # @return [void]
      def scopes=(value)
        @scopes = Array(value).flat_map { |scope| scope.to_s.split(",") }.map(&:strip).reject(&:empty?).uniq
      end

      private

      # @return [void]
      def set_default_options
        self.access_type = DEFAULT_ACCESS_TYPE if access_type.nil?
        self.after_install_path = DEFAULT_AFTER_INSTALL_PATH if after_install_path.nil?
        self.parent_controller = DEFAULT_PARENT_CONTROLLER if parent_controller.nil?
        self.scopes = DEFAULT_SCOPES if scopes.nil?
      end
    end
  end
end
