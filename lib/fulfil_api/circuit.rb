# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Circuit} tracks the health of one Fulfil instance. After
  #   `failure_threshold` failed requests within `window` seconds, the circuit opens
  #   and requests to that instance raise a {FulfilApi::Circuit::Open} straight away,
  #   without touching the network. After `cool_down` seconds the circuit closes
  #   again and requests go through as before.
  #
  # The state lives in an `ActiveSupport::Cache::Store`. The default store is held in
  #   memory, so every process tracks its circuits on its own. Pass a shared store
  #   (e.g. `Rails.cache`) to let all processes see the same state.
  #
  # @see FulfilApi::Configuration#circuit_breaker=
  class Circuit
    # The {FulfilApi::Circuit::Open} is raised instead of sending a request while the
    #   circuit of the Fulfil instance is open.
    class Open < FulfilApi::Error; end

    # The store used when the configuration doesn't provide one.
    DEFAULT_STORE = ActiveSupport::Cache::MemoryStore.new

    attr_reader :name

    # @param name [String] The name of the circuit, e.g. the host of the Fulfil instance.
    # @param failure_threshold [Integer] The number of failures that opens the circuit.
    # @param window [Numeric] The seconds within which the failures have to occur.
    # @param cool_down [Numeric] The seconds the circuit stays open.
    # @param store [ActiveSupport::Cache::Store, nil] Where the state is kept.
    def initialize(name, failure_threshold:, window:, cool_down:, store: nil)
      @name = name
      @failure_threshold = failure_threshold
      @window = window
      @cool_down = cool_down
      @store = store || DEFAULT_STORE
    end

    # @return [true, false] Whether requests to the Fulfil instance are being skipped.
    def open?
      store.exist?(open_key)
    end

    # Counts a failed request, and opens the circuit once the failures within the
    #   window reach the threshold.
    #
    # @return [void]
    def record_failure
      return if failure_count_after_increment < failure_threshold

      store.write(open_key, true, expires_in: cool_down)
      store.delete(failures_key)
    end

    private

    attr_reader :cool_down, :failure_threshold, :store, :window

    # Older versions of the in-memory store don't create a missing key on increment,
    #   so the first failure of a window is written explicitly when needed.
    #
    # @return [Integer]
    def failure_count_after_increment
      store.increment(failures_key, 1, expires_in: window) ||
        (store.write(failures_key, 1, expires_in: window, raw: true) && 1)
    end

    # @return [String]
    def failures_key
      "fulfil_api/circuit/#{name}/failures"
    end

    # @return [String]
    def open_key
      "fulfil_api/circuit/#{name}/open"
    end
  end
end
