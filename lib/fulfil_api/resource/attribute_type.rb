# frozen_string_literal: true

module FulfilApi
  class Resource
    # The {FulfilApi::Resource::AttributeType} enables parsing any attribute value
    #   returned by the Fulfil API. To preserve type information Fulfil extends the JSON format.
    #   When the response value is extended, it is considered castable.
    #
    # @example an extended attribute value (date)
    #   $ AttributeType.cast({ "__class__" => "date", "iso_string" => "2024-12-12" })
    #   => #<Date: 2024-08-30 />
    #
    # For all possible special
    class AttributeType
      # Casts any attribute value to its final form.
      #
      # @param value [Any] The attribute value to cast
      # @return [Any] The casted attribute value
      def self.cast(value)
        new(value).cast_value
      end

      # @param value [Any]
      def initialize(value)
        @type = extended?(value) ? value.fetch("__class__") : nil
        @value = value
      end

      # Casts the attribute value to an useable format for a Ruby application.
      #
      # @return [Any]
      def cast_value
        case @type
        when "bytes" then Base64.decode64(value_before_cast)
        when "date" then Date.parse(value_before_cast)
        when "datetime" then DateTime.parse(value_before_cast)
        when "decimal" then BigDecimal(value_before_cast)
        when "time" then Time.parse(value_before_cast)
        when "timedelta" then value_before_cast
        else
          @value
        end
      end

      # Retrieves the raw attribute value.
      #
      # @return [Any]
      def value_before_cast
        case @type
        when "bytes" then @value["base64"]
        when "date", "datetime", "time", "timedelta" then @value["iso_string"]
        when "decimal" then @value["decimal"]
        else
          @value
        end
      end

      private

      # The {#extended?} checks if the provided value is considered an extended
      #   attribute value.
      #
      # @param value [Any] The attribute value returned by Fulfil's API endpoint.
      # @return [true, false]
      def extended?(value)
        value.is_a?(Hash) && value.key?("__class__")
      end
    end
  end
end
