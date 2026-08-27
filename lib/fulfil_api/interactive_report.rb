# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::InteractiveReport} runs one of Fulfil's interactive reports and
  #   returns its raw result.
  #
  # Interactive reports are a different beast from the documents that
  #   {FulfilApi::Report} generates. They live on the model endpoint rather than the
  #   report endpoint, they take their parameters as a request body, and they answer
  #   with the rows of the report instead of a URL to download.
  #
  # @example Running the inventory quantity report for a single warehouse
  #   rows = FulfilApi::InteractiveReport.execute("inventory.quantity.ireport", warehouse: 12, show_products: :all)
  class InteractiveReport
    attr_reader :name

    # Runs the report in a single call.
    #
    # @param name [String] The name of the report (e.g. "inventory.quantity.ireport").
    # @param parameters [Hash] The parameters to run the report with.
    # @return [Array, Hash] The raw result of the report.
    def self.execute(name, **parameters)
      new(name).execute(**parameters)
    end

    # @param name [String] The name of the report (e.g. "inventory.quantity.ireport").
    def initialize(name)
      @name = name
    end

    # Runs the report with the given parameters.
    #
    # @param parameters [Hash] The parameters to run the report with.
    # @return [Array, Hash] The raw result of the report.
    def execute(**parameters)
      FulfilApi.client.put("/model/#{name}/execute", body: [serialize(parameters)])
    end

    private

    # @param parameters [Hash] The parameters to run the report with.
    # @return [Hash] The parameters in the extended JSON format Fulfil expects.
    def serialize(parameters)
      parameters.transform_values { |value| serialize_value(value) }
    end

    # Fulfil extends JSON to preserve type information, and expects the same
    #   extended format on the way in for anything it can't express in plain JSON.
    #
    # @param value [Any] The parameter value.
    # @return [Any] The value in the format Fulfil expects.
    def serialize_value(value)
      case value
      when Date then { "__class__" => "date", "year" => value.year, "month" => value.month, "day" => value.day }
      else value
      end
    end
  end
end
