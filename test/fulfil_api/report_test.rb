# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class ReportTest < Minitest::Test
    def setup
      @merchant_id = "merchant-#{SecureRandom.uuid}"

      FulfilApi.configure do |config|
        config.merchant_id = @merchant_id
        config.access_token = FulfilApi::AccessToken.new(SecureRandom.uuid)
      end
    end

    def test_generate_makes_put_request_to_report_endpoint
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      FulfilApi::Report.generate("account.invoice.html", 3991)

      assert_requested :put, %r{#{@merchant_id}.fulfil.io/api/v2/report/account.invoice.html}i
    end

    def test_generate_wraps_id_in_an_array
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      FulfilApi::Report.generate("account.invoice.html", 3991)

      assert_requested :put, %r{report/account.invoice.html}i do |request|
        body = JSON.parse(request.body)

        assert_equal [3991], body["objects"]
      end
    end

    def test_generate_sends_id_and_data_in_request_body
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      FulfilApi::Report.generate("account.invoice.html", 3991, data: { language: "en" })

      assert_requested :put, %r{report/account.invoice.html}i do |request|
        body = JSON.parse(request.body)

        assert_equal [3991], body["objects"]
        assert_equal({ "language" => "en" }, body["data"])
      end
    end

    def test_generate_defaults_data_to_empty_hash
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      FulfilApi::Report.generate("account.invoice.html", 3991)

      assert_requested :put, %r{report/account.invoice.html}i do |request|
        body = JSON.parse(request.body)

        assert_empty(body["data"])
      end
    end

    def test_generate_returns_report_with_filename
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      report = FulfilApi::Report.generate("account.invoice.html", 3991)

      assert_equal "Invoice.pdf", report.filename
    end

    def test_generate_returns_report_with_mimetype
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      report = FulfilApi::Report.generate("account.invoice.html", 3991)

      assert_equal "application/pdf", report.mimetype
    end

    def test_generate_returns_report_with_url
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      report = FulfilApi::Report.generate("account.invoice.html", 3991)

      assert_equal "https://example.com/invoice.pdf", report.url
    end

    def test_download_returns_a_tempfile_with_report_contents
      pdf_content = "%PDF-1.4 fake content"

      stub_request(:get, "https://example.com/invoice.pdf")
        .to_return(status: 200, body: pdf_content)

      report = FulfilApi::Report.new(
        filename: "Invoice.pdf",
        mimetype: "application/pdf",
        url: "https://example.com/invoice.pdf"
      )

      tempfile = report.download

      assert_instance_of Tempfile, tempfile
      assert_equal pdf_content, tempfile.read
    ensure
      tempfile&.close!
    end

    def test_download_preserves_file_extension
      stub_request(:get, "https://example.com/invoice.pdf")
        .to_return(status: 200, body: "content")

      report = FulfilApi::Report.new(
        filename: "Invoice.pdf",
        mimetype: "application/pdf",
        url: "https://example.com/invoice.pdf"
      )

      tempfile = report.download

      assert_match(/\.pdf\z/, tempfile.path)
    ensure
      tempfile&.close!
    end

    def test_download_rewinds_tempfile_for_immediate_reading
      stub_request(:get, "https://example.com/invoice.pdf")
        .to_return(status: 200, body: "file content")

      report = FulfilApi::Report.new(
        filename: "Invoice.pdf",
        mimetype: "application/pdf",
        url: "https://example.com/invoice.pdf"
      )

      tempfile = report.download

      assert_equal 0, tempfile.pos
    ensure
      tempfile&.close!
    end

    def test_generate_raises_error_on_api_failure
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        status: 422,
        response: { error: "something went wrong" }
      )

      error =
        assert_raises FulfilApi::Error do
          FulfilApi::Report.generate("account.invoice.html", 3991)
        end

      assert_equal 422, error.details[:response_status]
    end
  end
end
