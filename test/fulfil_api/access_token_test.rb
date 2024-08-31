# frozen_string_literal: true

require "test_helper"

module FulfilApi
  class AccessTokenTest < Minitest::Test
    def setup
      @token = SecureRandom.uuid
    end

    def test_raising_on_invalid_token_types
      assert_raises FulfilApi::AccessToken::TypeInvalid do
        FulfilApi::AccessToken.new(@token, type: :invalid_type).to_http_header
      end
    end

    def test_returning_the_http_header_without_token_type_defined
      assert_equal(
        { "X-API-KEY" => @token },
        FulfilApi::AccessToken.new(@token).to_http_header
      )
    end

    def test_returning_the_http_header_for_personal_access_tokens
      assert_equal(
        { "X-API-KEY" => @token },
        FulfilApi::AccessToken.new(@token, type: :personal).to_http_header
      )
    end

    def test_returning_the_http_header_for_oauth_access_tokens
      assert_equal(
        { "Authorization" => "Bearer #{@token}" },
        FulfilApi::AccessToken.new(@token, type: :oauth).to_http_header
      )
    end
  end
end
