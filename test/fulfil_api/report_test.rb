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

      FulfilApi::Report.generate("account.invoice.html", ids: [3991])

      assert_requested :put, %r{#{@merchant_id}.fulfil.io/api/v2/report/account.invoice.html}i
    end

    def test_generate_sends_ids_and_data_in_request_body
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      FulfilApi::Report.generate("account.invoice.html", ids: [3991], data: { language: "en" })

      assert_requested :put, %r{report/account.invoice.html}i do |request|
        body = JSON.parse(request.body)
        assert_equal [3991], body["ids"]
        assert_equal({ "language" => "en" }, body["data"])
      end
    end

    def test_generate_defaults_data_to_empty_hash
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      FulfilApi::Report.generate("account.invoice.html", ids: [3991])

      assert_requested :put, %r{report/account.invoice.html}i do |request|
        body = JSON.parse(request.body)
        assert_equal({}, body["data"])
      end
    end

    def test_generate_returns_report_with_filename
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      report = FulfilApi::Report.generate("account.invoice.html", ids: [3991])

      assert_equal "Invoice.pdf", report.filename
    end

    def test_generate_returns_report_with_mimetype
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      report = FulfilApi::Report.generate("account.invoice.html", ids: [3991])

      assert_equal "application/pdf", report.mimetype
    end

    def test_generate_returns_report_with_url
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        response: { filename: "Invoice.pdf", mimetype: "application/pdf", url: "https://example.com/invoice.pdf" }
      )

      report = FulfilApi::Report.generate("account.invoice.html", ids: [3991])

      assert_equal "https://example.com/invoice.pdf", report.url
    end

    def test_generate_raises_error_on_api_failure
      stub_fulfil_report_request(
        report_name: "account.invoice.html",
        status: 422,
        response: { error: "something went wrong" }
      )

      error =
        assert_raises FulfilApi::Error do
          FulfilApi::Report.generate("account.invoice.html", ids: [3991])
        end

      assert_equal 422, error.details[:response_status]
    end
  end
end
