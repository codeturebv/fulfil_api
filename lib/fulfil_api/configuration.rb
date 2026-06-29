# frozen_string_literal: true

module FulfilApi
  # Configuration model for the Fulfil gem.
  #
  # This model holds configuration settings and provides thread-safe access
  #   to these settings.
  class Configuration
    attr_accessor :access_token, :api_version, :merchant_id, :request_options, :tpl
    attr_reader :connection_options

    DEFAULT_API_VERSION = "v2"
    DEFAULT_REQUEST_OPTIONS = { open_timeout: 1, read_timeout: 5, write_timeout: 5, timeout: 5 }.freeze

    # Tuning for the persistent (keep-alive) HTTP connection.
    #
    # `max_retries` re-enables Ruby's built-in retry for idempotent requests
    #   (GET/HEAD/PUT/DELETE/OPTIONS). The `net_http_persistent` adapter forces
    #   it to 0, which means a keep-alive socket the server has already dropped
    #   surfaces as a read timeout instead of being transparently retried on a
    #   fresh socket. POST is never auto-retried, so this is side-effect safe.
    #
    # `idle_timeout` and `pool_size` are passed through to the underlying
    #   Net::HTTP::Persistent connection when set.
    DEFAULT_CONNECTION_OPTIONS = { max_retries: 1 }.freeze

    # Initializes the configuration with optional settings.
    #
    # @param options [Hash, nil] An optional list of configuration options.
    #   Each key in the hash should correspond to a configuration attribute.
    def initialize(options = {})
      # Assigns the optional configuration options
      options.each_pair do |key, value|
        send(:"#{key}=", value) if respond_to?(:"#{key}=")
      end

      # Sets the default options if not provided
      set_default_options
    end

    # Merges the provided connection options over the defaults so that, for
    #   example, setting only `idle_timeout` still keeps the default
    #   `max_retries`. Assigning `nil` resets to the defaults.
    #
    # @param options [Hash, nil] The connection options to apply.
    # @return [void]
    def connection_options=(options)
      @connection_options = DEFAULT_CONNECTION_OPTIONS.merge(options || {})
    end

    private

    # Sets the default options for the gem configuration.
    #
    # This method is called during initialization to ensure all configuration
    #   options have sensible defaults if not explicitly set.
    #
    # @return [void]
    def set_default_options
      self.api_version = DEFAULT_API_VERSION if api_version.nil?
      self.request_options = DEFAULT_REQUEST_OPTIONS if request_options.nil?
      self.connection_options = nil if connection_options.nil?
    end
  end

  @configuration = Configuration.new

  # Provides thread-safe access to the gem's configuration.
  #
  # @return [Fulfil::Configuration] The current configuration object.
  def self.configuration
    Thread.current[:fulfil_api_configuration] ||=
      @configuration ||= Configuration.new
  end

  # Allows the configuration of the gem in a thread-safe manner.
  #
  # @yieldparam [Fulfil::Configuration] config The current configuration object.
  # @return [void]
  def self.configure
    yield(configuration)
  end

  # Overwrites the configuration with the newly provided configuration options.
  #
  # @param options [Hash, Fulfil::Configuration] A list of configuration options for the gem.
  # @return [Fulfil::Configuration] The updated configuration object.
  def self.configuration=(options_or_configuration) # rubocop:disable Metrics/MethodLength
    Thread.current[:fulfil_api_configuration] =
      case options_or_configuration
      when Hash
        config = Configuration.new
        options_or_configuration.each { |key, value| config.send(:"#{key}=", value) }
        config
      when Configuration
        options_or_configuration
      else
        raise ArgumentError, "Expected Hash or Configuration, got #{options_or_configuration.class} instead"
      end
  end

  # Temporarily applies the provided configuration options on top of the
  #   currently active configuration, and then reverts after the block executes.
  #
  # The temporary options are merged over a copy of the active configuration, so
  #   a block only needs to specify what it overrides — credentials and other
  #   settings (`access_token`, `merchant_id`, ...) are inherited rather than
  #   reset to their defaults.
  #
  # @param temporary_options [Hash] A hash of temporary configuration options.
  # @yield Executes the block with the temporary configuration.
  # @return [void]
  def self.with_config(temporary_options)
    original_configuration = configuration

    self.configuration = original_configuration.dup.tap do |config|
      temporary_options.each { |key, value| config.public_send(:"#{key}=", value) }
    end

    yield
  ensure
    # Revert to the original configuration
    Thread.current[:fulfil_api_configuration] = original_configuration
  end
end
