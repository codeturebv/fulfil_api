# frozen_string_literal: true

module Fulfil
  # Configuration model for the Fulfil gem.
  #
  # This model holds configuration settings and provides thread-safe access
  #   to these settings.
  class Configuration
    attr_accessor :api_version, :merchant_id

    # Initializes the configuration with optional settings.
    #
    # @param options [Hash, nil] An optional list of configuration options.
    #   Each key in the hash should correspond to a configuration attribute.
    def initialize(options = {})
      @mutex = Mutex.new

      # Assigns the optional configuration options
      options.each_pair do |key, value|
        send(:"#{key}=", value) if respond_to?(:"#{key}=")
      end

      # Sets the default options if not provided
      set_default_options
    end

    # Provides thread-safe access to missing methods, allowing dynamic handling of configuration options.
    #
    # @param method [Symbol] The method name.
    # @param args [Array] The arguments passed to the method.
    # @param block [Proc] An optional block passed to the method.
    # @return [void]
    def method_missing(method, *args, &block)
      @mutex.synchronize { super }
    end

    # Ensures that the object responds correctly to methods handled by method_missing.
    #
    # @param method [Symbol] The method name.
    # @param include_private [Boolean] Whether to include private methods.
    # @return [Boolean] Whether the object responds to the method.
    def respond_to_missing?(method, include_private = false)
      @mutex.synchronize { super }
    end

    private

    # Sets the default options for the gem configuration.
    # This method is called during initialization to ensure all configuration
    # options have sensible defaults if not explicitly set.
    #
    # @return [void]
    def set_default_options
      self.api_version = "2.0" if api_version.nil?
    end
  end

  @configuration = Configuration.new
  @configuration_mutex = Mutex.new

  # Provides thread-safe access to the gem's configuration.
  #
  # @return [Fulfil::Configuration] The current configuration object.
  def self.configuration
    @configuration_mutex.synchronize do
      @configuration
    end
  end

  # Allows the configuration of the gem in a thread-safe manner.
  #
  # @yieldparam [Fulfil::Configuration] config The current configuration object.
  # @return [void]
  def self.configure
    @configuration_mutex.synchronize do
      yield(@configuration)
    end
  end

  # Overwrites the configuration with the newly provided configuration options.
  #
  # @param options [Hash, Fulfil::Configuration] A list of configuration options for the gem.
  # @return [Fulfil::Configuration] The updated configuration object.
  def self.configuration=(options_or_configuration)
    @configuration_mutex.synchronize do
      if options_or_configuration.is_a?(Hash)
        options_or_configuration.each_pair do |key, value|
          @configuration.send(:"#{key}=", value) if @configuration.respond_to?(:"#{key}=")
        end
      elsif options_or_configuration.is_a?(Configuration)
        @configuration = options_or_configuration
      end
    end
  end

  # Temporarily applies the provided configuration options within a block,
  # and then reverts to the original configuration after the block executes.
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
    self.configuration = original_configuration
  end
end
