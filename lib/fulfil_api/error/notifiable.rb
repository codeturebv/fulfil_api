# frozen_string_literal: true

module FulfilApi
  class Error
    # The {FulfilApi::Error::Notifiable} publishes an {ActiveSupport::Notifications}
    #   event every time a {FulfilApi::Error} is raised. It gives an application a
    #   single place to report a failure of the Fulfil API to its APM — a counter of
    #   rate limit hits, an error tracker, a log line — without having to wrap every
    #   call into the gem in a `begin`/`rescue`.
    #
    # Ruby routes every form of `raise` through {Exception.exception} (when raising a
    #   class) or {Exception#exception} (when raising an instance), which makes those
    #   two methods the hook for "an error is on its way up the stack". Building an
    #   error without raising it — {FulfilApi::HttpError.from_faraday_error}, for
    #   example — publishes nothing.
    #
    # @example counting the errors of Fulfil in an APM
    #   # config/initializers/fulfil_api.rb
    #   FulfilApi.on_error do |error|
    #     Appsignal.increment_counter("fulfil_api_errors", 1, error: error.class.name)
    #   end
    #
    # @example subscribing through ActiveSupport directly, for the full payload
    #   ActiveSupport::Notifications.subscribe(FulfilApi::Error::EVENT_NAME) do |event|
    #     Rails.logger.warn("Fulfil responded with #{event.payload[:status_code]}")
    #   end
    #
    # @note A subscriber must not change the behaviour of the application it observes.
    #   An exception raised by a subscriber is therefore swallowed and reported on
    #   `$stderr` rather than allowed to replace the {FulfilApi::Error} on its way up.
    module Notifiable
      extend ActiveSupport::Concern

      # The name of the published event. It follows the `<action>.<library>` naming
      #   convention of Rails, so an APM that subscribes to a whole library through a
      #   `/\.fulfil_api\z/` regexp picks it up along with everything the gem may
      #   instrument in the future.
      EVENT_NAME = "error.fulfil_api"

      # The key of the fiber local flag guarding against infinite recursion. A
      #   subscriber that itself raises a {FulfilApi::Error} — one calling back into
      #   Fulfil, for instance — would otherwise publish an event from within the
      #   publication of an event, without end.
      REENTRANCY_KEY = :fulfil_api_notifying_error

      class_methods do
        # Publishes {EVENT_NAME} for `raise SomeError` and `raise SomeError, "message"`.
        #
        # @return [FulfilApi::Error] The error being raised.
        def exception(*, **)
          super.tap(&:notify)
        end
      end

      # Publishes {EVENT_NAME} for `raise error` and `raise error, "message"`.
      #
      # @return [FulfilApi::Error] The error being raised.
      def exception(*)
        super.tap(&:notify)
      end

      # Publishes {EVENT_NAME} for the receiver.
      #
      # @return [void]
      def notify
        return if Thread.current[REENTRANCY_KEY]

        Thread.current[REENTRANCY_KEY] = true
        ActiveSupport::Notifications.instrument(EVENT_NAME, notification_payload)
      rescue StandardError => e
        warn "[FulfilApi] a subscriber of #{EVENT_NAME} raised #{e.class}: #{e.message}"
      ensure
        Thread.current[REENTRANCY_KEY] = nil
      end

      private

      # The payload published alongside {EVENT_NAME}.
      #
      # `:exception` and `:exception_object` follow the convention Rails uses for its
      #   own instrumentation, which is what an APM looks for to attribute an event to
      #   a failure.
      #
      # @return [Hash]
      def notification_payload
        { exception: [self.class.name, message], exception_object: self }
      end
    end
  end
end
