# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Report} class provides an interface for generating reports
  # (e.g., PDF invoices) via Fulfil's report API. The API returns a temporary
  # URL where the generated document can be downloaded.
  #
  # @example Generate an invoice PDF
  #   report = FulfilApi::Report.generate("account.invoice.html", ids: [3991])
  #   report.url       # => "https://..."
  #   report.filename  # => "Invoice.pdf"
  #   report.mimetype  # => "application/pdf"
  class Report
    attr_reader :filename, :mimetype, :url

    # @param filename [String] The filename of the generated report.
    # @param mimetype [String] The MIME type of the generated report.
    # @param url [String] The temporary URL to download the generated report.
    def initialize(filename:, mimetype:, url:)
      @filename = filename
      @mimetype = mimetype
      @url = url
    end

    # Generates a report for the given record IDs.
    #
    # @param report_name [String] The report identifier (e.g., "account.invoice.html").
    # @param ids [Array<Integer>] The record IDs to generate the report for.
    # @param data [Hash] Optional additional data for the report.
    # @return [FulfilApi::Report] A report object with filename, mimetype, and url.
    def self.generate(report_name, ids:, data: {})
      response = FulfilApi.client.put("report/#{report_name}", body: { ids: ids, data: data })

      new(
        filename: response["filename"],
        mimetype: response["mimetype"],
        url: response["url"]
      )
    end
  end
end
