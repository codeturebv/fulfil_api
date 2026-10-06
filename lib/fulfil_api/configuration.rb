# frozen_string_literal: true

module FulfilApi
  # Configuration model for the Fulfil gem.
  #
  # This model holds configuration settings and provides thread-safe access
  #   to these settings.
  class Configuration
    attr_accessor :access_token, :api_version, :merchant_id, :request_options, :tpl
    attr_reader :connection_options, :retry_options

    # @!attribute [rw] circuit_breaker
    #   @return [Faulty, nil] The Faulty instance that runs every request through a
    #     circuit per Fulfil instance, or nil to turn the circuit breaker off. See
    #     {FulfilApi::Middleware::CircuitBreaker}.
    attr_accessor :circuit_breaker

    DEFAULT_API_VERSION = "v2"
    DEFAULT_REQUEST_OPTIONS = { open_timeout: 1, read_timeout: 5, write_timeout: 5, timeout: 5 }.freeze

    # Tuning for the persistent (keep-alive) HTTP connection.
    #
    # `idle_timeout` and `pool_size` are passed through to the underlying
    #   Net::HTTP::Persistent connection when set.
    #
    # `max_retries` re-enables Ruby's built-in retry, which retries every request
    #   Net::HTTP considers idempotent (GET/HEAD/PUT/DELETE/OPTIONS) whatever its
    #   endpoint. Fulfil writes through PUT too, so it is off by default in favour
    #   of the endpoint scoped {#retry_options}.
    DEFAULT_CONNECTION_OPTIONS = {}.freeze

    # Retries for requests that failed before Fulfil could answer them: a dropped
    #   keep-alive socket, a refused connection or a timeout.
    #
    # `max_retries` caps the number of retries per request. `requests` maps an
    #   HTTP verb onto the endpoints that are safe to retry, either `true` for every
    #   endpoint or a list of patterns matched against the request path. Reads in
    #   Fulfil go out as PUT requests to `search_read` and `search_count`, so those
    #   are retried; every other PUT may write and is not.
    DEFAULT_RETRY_OPTIONS = {
      max_retries: 1,
      requests: {
        get: true,
        put: [%r{/search_read\z}, %r{/search_count\z}]
      }
    }.freeze

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

    # Merges the provided retry options over the defaults. Assigning `nil` resets
    #   to the defaults.
    #
    # @example retrying reads three times, and one write endpoint as well
    #   config.retry_options = {
    #     max_retries: 3,
    #     requests: { get: true, put: [%r{/search_read\z}, %r{/stock.shipment.out/hold\z}] }
    #   }
    #
    # @param options [Hash, nil] The retry options to apply.
    # @return [void]
    def retry_options=(options)
      @retry_options = DEFAULT_RETRY_OPTIONS.merge(options || {})
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
      self.retry_options = nil if retry_options.nil?
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
