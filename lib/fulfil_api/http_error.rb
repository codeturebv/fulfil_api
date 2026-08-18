# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::HttpError} is raised whenever a request to an API endpoint of
  #   Fulfil fails.
  #
  # Every HTTP status code Fulfil can respond with has a dedicated subclass, named
  #   after the status code it represents. A 429 response raises a
  #   {FulfilApi::HttpError::TooManyRequests}, a 422 an
  #   {FulfilApi::HttpError::UnprocessableEntity}, and so on. See {STATUS_CODES} for
  #   the full list. This lets callers rescue the exact failure they care about
  #   instead of rescuing everything and inspecting the status code themselves.
  #
  # Requests that never reached Fulfil — a connection reset, a DNS failure, a
  #   timeout — have no status code to name and raise a {FulfilApi::HttpError}.
  #
  # @example rescuing one specific HTTP status code
  #   begin
  #     FulfilApi::Resource.set(model_name: "sale.sale").find_by(["id", "=", 100])
  #   rescue FulfilApi::HttpError::TooManyRequests => exception
  #     sleep exception.response_headers["retry-after"].to_i
  #     retry
  #   end
  #
  # @example rescuing any failed request
  #   begin
  #     FulfilApi::Resource.set(model_name: "sale.sale").find_by(["id", "=", 100])
  #   rescue FulfilApi::HttpError => exception
  #     Rails.logger.error("Fulfil responded with #{exception.status_code}: #{exception.message}")
  #   end
  #
  # @note {FulfilApi::HttpError} inherits from {FulfilApi::Error}, so any code that
  #   already rescues {FulfilApi::Error} keeps catching these exceptions.
  class HttpError < Error
    # The keys of an error response of Fulfil that can hold the human readable
    #   message, in the order they're preferred.
    #
    # Fulfil is not consistent in how it reports failures: HTTP level errors carry a
    #   `description`, application level errors a `message`, and a handful of
    #   endpoints only return an `error`.
    MESSAGE_KEYS = %w[description message error].freeze

    # Maps an HTTP status code onto the name of the {FulfilApi::HttpError} subclass
    #   representing it.
    STATUS_CODES = {
      400 => :BadRequest,
      401 => :Unauthorized,
      402 => :PaymentRequired,
      403 => :Forbidden,
      404 => :NotFound,
      405 => :MethodNotAllowed,
      406 => :NotAcceptable,
      407 => :ProxyAuthenticationRequired,
      408 => :RequestTimeout,
      409 => :Conflict,
      410 => :Gone,
      411 => :LengthRequired,
      412 => :PreconditionFailed,
      413 => :PayloadTooLarge,
      414 => :UriTooLong,
      415 => :UnsupportedMediaType,
      416 => :RangeNotSatisfiable,
      417 => :ExpectationFailed,
      418 => :ImATeapot,
      421 => :MisdirectedRequest,
      422 => :UnprocessableEntity,
      423 => :Locked,
      424 => :FailedDependency,
      425 => :TooEarly,
      426 => :UpgradeRequired,
      428 => :PreconditionRequired,
      429 => :TooManyRequests,
      431 => :RequestHeaderFieldsTooLarge,
      451 => :UnavailableForLegalReasons,
      500 => :InternalServerError,
      501 => :NotImplemented,
      502 => :BadGateway,
      503 => :ServiceUnavailable,
      504 => :GatewayTimeout,
      505 => :HttpVersionNotSupported,
      506 => :VariantAlsoNegotiates,
      507 => :InsufficientStorage,
      508 => :LoopDetected,
      510 => :NotExtended,
      511 => :NetworkAuthenticationRequired
    }.freeze

    # Defines a dedicated exception class for every status code in {STATUS_CODES} and
    #   indexes them by their status code, so {.for_status_code} can look one up
    #   without going through {Module#const_get}.
    CLASSES_BY_STATUS_CODE = STATUS_CODES.transform_values do |class_name|
      const_set(class_name, Class.new(self))
    end.freeze

    class << self
      # Looks up the {FulfilApi::HttpError} subclass representing the given HTTP
      #   status code.
      #
      # @param status_code [Integer, nil] The HTTP status code of the response.
      # @return [Class<FulfilApi::HttpError>] The subclass for the status code, or
      #   {FulfilApi::HttpError} itself when the status code is unknown or absent.
      def for_status_code(status_code)
        CLASSES_BY_STATUS_CODE.fetch(status_code, HttpError)
      end

      # Builds the most specific {FulfilApi::HttpError} for the given Faraday exception.
      #
      # @param exception [Faraday::Error] Any error raised by Faraday during the
      #   execution of the HTTP request to the API endpoint.
      # @return [FulfilApi::HttpError]
      def from_faraday_error(exception)
        details = {
          response_body: exception.response_body,
          response_headers: exception.response_headers,
          response_status: exception.response_status
        }

        for_status_code(exception.response_status).new(
          message_from(exception.response_body) || exception.message, details: details
        )
      end

      private

      # Extracts the human readable error message out of the response body of Fulfil.
      #
      # @param response_body [String, Hash, nil] The response body of the API endpoint.
      # @return [String, nil] The message, or nil when the body holds none. An HTML
      #   error page and an empty body both yield nil.
      def message_from(response_body)
        body = parse(response_body)
        return if body.nil?

        MESSAGE_KEYS.map { |key| body[key] }.find { |message| message.is_a?(String) && message.present? }
      end

      # @param response_body [String, Hash, nil] The response body of the API endpoint.
      # @return [ActiveSupport::HashWithIndifferentAccess, nil]
      def parse(response_body)
        return response_body.with_indifferent_access if response_body.is_a?(Hash)
        return if response_body.blank?

        parsed_body = JSON.parse(response_body)
        parsed_body.with_indifferent_access if parsed_body.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end
    end

    # Unlike {FulfilApi::Error}, the message is returned as-is. The name of the
    #   exception class already tells you what went wrong, so prefixing it only gets
    #   in the way of the description reported by Fulfil.
    #
    # @note {StandardError#message} delegates to {StandardError#to_s}, which still
    #   holds the message passed to the constructor.
    #
    # @return [String]
    def message
      to_s
    end

    # @return [String, Hash, nil] The raw response body of the API endpoint of Fulfil.
    def response_body
      details&.dig(:response_body)
    end

    # @return [Hash, nil] The response headers of the API endpoint of Fulfil.
    def response_headers
      details&.dig(:response_headers)
    end

    # @return [Integer, nil] The HTTP status code of the response, or nil when the
    #   request never reached Fulfil.
    def status_code
      details&.dig(:response_status)
    end

    private

    # Enriches the payload published by {FulfilApi::Error::Notifiable} with what
    #   Fulfil reported, so a subscriber can tag its metrics by status code without
    #   having to unpack the exception itself.
    #
    # @return [Hash]
    def notification_payload
      super.merge(
        response_body: response_body,
        response_headers: response_headers,
        status_code: status_code
      )
    end
  end
end
