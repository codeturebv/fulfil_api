# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Deadline} is a time budget for a unit of work against Fulfil, like
  #   the handful of requests one web request makes. Once it runs out, no further
  #   requests are sent and a {FulfilApi::Deadline::Exceeded} is raised instead.
  #
  # The deadline decides whether a request may start, not how long it may take. Each
  #   request is still bound by the configured `request_options`, so the worst case
  #   is the deadline plus the timeouts of the last request started within it. The
  #   timeouts can't be shortened per request: they're set on the persistent
  #   connection, which is shared between threads.
  #
  # @see FulfilApi.with_deadline
  class Deadline
    # The {FulfilApi::Deadline::Exceeded} is raised when a request would start after
    #   the deadline ran out.
    class Exceeded < FulfilApi::Error; end

    attr_reader :expires_at

    # @return [FulfilApi::Deadline, nil] The deadline of the current thread, if any.
    def self.current
      Thread.current[:fulfil_api_deadline]
    end

    # @return [Float] The current time of the monotonic clock in seconds.
    def self.now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # @param seconds [Numeric] The time budget in seconds.
    def initialize(seconds)
      @expires_at = self.class.now + seconds
    end

    # @return [true, false] Whether the time budget has run out.
    def expired?
      remaining <= 0
    end

    # @return [Float] The seconds left in the time budget, negative once it's expired.
    def remaining
      expires_at - self.class.now
    end
  end

  # Runs the block within a time budget for requests to Fulfil. Requests that would
  #   start after the budget ran out raise a {FulfilApi::Deadline::Exceeded} instead.
  #
  # A nested deadline can only shorten the deadline around it, never extend it.
  #
  # @example failing fast in a web request
  #   FulfilApi.with_deadline(3) do
  #     FulfilApi::Resource.set(model_name: "stock.shipment.out").where(["id", "=", 1]).to_a
  #   end
  #
  # @param seconds [Numeric, nil] The time budget in seconds. Defaults to the
  #   configured `deadline`; without either, the block runs without a deadline.
  # @yield The work to run within the time budget.
  # @return [Object] The return value of the block.
  def self.with_deadline(seconds = configuration.deadline)
    original_deadline = Deadline.current
    return yield if seconds.nil?

    deadline = Deadline.new(seconds)
    deadline = original_deadline if original_deadline && original_deadline.expires_at < deadline.expires_at

    begin
      Thread.current[:fulfil_api_deadline] = deadline
      yield
    ensure
      Thread.current[:fulfil_api_deadline] = original_deadline
    end
  end
end
