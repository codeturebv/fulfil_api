# frozen_string_literal: true

module FulfilApi
  # The {FulfilApi::Report} class provides an interface for generating reports
  # (e.g., PDF invoices) via Fulfil's report API. The API returns a temporary
  # URL where the generated document can be downloaded.
  #
  # @example Generate and download an invoice PDF
  #   report = FulfilApi::Report.generate("account.invoice.html", 3991)
  #   report.url       # => "https://..."
  #   report.filename  # => "Invoice.pdf"
  #   report.mimetype  # => "application/pdf"
  #
  #   tempfile = report.download
  #   tempfile.path    # => "/tmp/fulfil_report20260324-12345.pdf"
  class Report
    attr_reader :filename, :mimetype, :url

    # Generates a report for the given record ID.
    #
    # @param report_name [String] The report identifier (e.g., "account.invoice.html").
    # @param id [Integer] The record ID to generate the report for.
    # @param data [Hash] Optional additional data for the report.
    # @return [FulfilApi::Report] A report object with filename, mimetype, and url.
    def self.generate(report_name, id, data: {})
      response = FulfilApi.client.put("report/#{report_name}", body: { objects: [id], data: data })

      new(
        filename: response["filename"],
        mimetype: response["mimetype"],
        url: response["url"]
      )
    end

    # @param filename [String] The filename of the generated report.
    # @param mimetype [String] The MIME type of the generated report.
    # @param url [String] The temporary URL to download the generated report.
    def initialize(filename:, mimetype:, url:)
      @filename = filename
      @mimetype = mimetype
      @url = url
    end

    # Downloads the report from the temporary URL and returns a {Tempfile}.
    #
    # The tempfile preserves the file extension from the report's filename
    # (e.g., ".pdf") so it can be used directly with file upload APIs.
    #
    # @return [Tempfile] A tempfile containing the downloaded report.
    def download
      response = Faraday.get(url)

      extension = File.extname(filename)
      tempfile = Tempfile.new(["fulfil_report", extension])
      tempfile.binmode
      tempfile.write(response.body)
      tempfile.rewind
      tempfile
    end
  end
end
