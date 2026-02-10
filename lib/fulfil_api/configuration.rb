# frozen_string_literal: true

module FulfilApi
  # Configuration model for the Fulfil gem.
  #
  # This model holds configuration settings and provides thread-safe access
  #   to these settings.
  class Configuration
    attr_accessor :access_token, :api_version, :merchant_id, :request_options, :tpl

    DEFAULT_API_VERSION = "v2"
    DEFAULT_REQUEST_OPTIONS = { open_timeout: 1, read_timeout: 5, write_timeout: 5, timeout: 5 }.freeze

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

  # Temporarily applies the provided configuration options within a block,
  #   and then reverts to the original configuration after the block executes.
  #
  # @param temporary_options [Hash] A hash of temporary configuration options.
  # @yield Executes the block with the temporary configuration.
  # @return [void]
  def self.with_config(temporary_options)
    original_configuration = configuration.dup
    self.configuration = temporary_options

    yield
  ensure
    # Revert to the original configuration
    Thread.current[:fulfil_api_configuration] = original_configuration
  end
end
