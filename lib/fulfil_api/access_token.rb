# frozen_string_literal: true

module FulfilApi
  # The {Fulfil::AccessToken} provides information about the type of access token
  #   that is provided to access the Fulfil API.
  class AccessToken
    attr_reader :value, :type

    class TypeInvalid < Error; end

    # @param value [String] The raw access token contents
    # @param type [Symbol, String] The access token type (personal or oauth)
    def initialize(value, type: :personal)
      @type = type.to_sym
      @value = value
    end

    # Builds the HTTP headers for the access token based on the {#type}.
    #
    # @return [Hash]
    def to_http_header
      case type
      when :personal
        { "X-API-KEY" => value }
      when :oauth
        { "Authorization" => "Bearer #{value}" }
      else
        raise TypeInvalid, "#{type} is not a valid access token type. Use :personal or :oauth instead."
      end
    end
  end
end
