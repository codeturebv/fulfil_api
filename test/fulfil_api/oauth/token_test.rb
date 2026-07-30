# frozen_string_literal: true

require "test_helper"

module FulfilApi
  module OAuth
    class TokenTest < Minitest::Test
      def offline_payload
        {
          "access_token" => "user-1234",
          "associated_user" => { "email" => "first.last@example.com", "id" => 1, "name" => "First Last" },
          "expires_in" => 3600,
          "offline_access_token" => "bot-1234",
          "scope" => ["user_session,sale.sale"],
          "token_type" => "Bearer"
        }
      end

      def test_reads_the_granted_token
        token = Token.new(offline_payload)

        assert_equal "user-1234", token.access_token
        assert_equal "bot-1234", token.offline_access_token
        assert_equal "Bearer", token.token_type
        assert_equal 3600, token.expires_in
        assert_equal "first.last@example.com", token.associated_user[:email]
      end

      def test_flattens_the_comma_separated_scopes_of_fulfil
        token = Token.new(offline_payload)

        assert_equal %w[user_session sale.sale], token.scopes
      end

      def test_prefers_the_permanent_token_over_the_short_lived_one
        assert_equal "bot-1234", Token.new(offline_payload).value
        assert_equal "user-1234", Token.new(offline_payload.except("offline_access_token")).value
      end

      def test_offline_reflects_whether_a_permanent_token_was_granted
        assert_predicate Token.new(offline_payload), :offline?
        refute_predicate Token.new(offline_payload.except("offline_access_token")), :offline?
      end

      def test_converts_into_an_oauth_access_token
        access_token = Token.new(offline_payload).to_access_token

        assert_equal :oauth, access_token.type
        assert_equal({ "Authorization" => "Bearer bot-1234" }, access_token.to_http_header)
      end

      def test_expires_at_is_derived_from_the_lifetime
        assert_in_delta (Time.now.utc + 3600).to_f, Token.new(offline_payload).expires_at.to_f, 5
      end

      def test_expires_at_is_unknown_without_a_lifetime
        assert_nil Token.new(offline_payload.except("expires_in")).expires_at
      end

      def test_defaults_to_a_bearer_token_type
        assert_equal Token::DEFAULT_TOKEN_TYPE, Token.new({}).token_type
      end
    end
  end
end
