# frozen_string_literal: true

module FulfilApi
  # Raised when Fulfil rejected the credentials a request was made with, because
  #   the access token expired, was revoked, or was never valid.
  #
  # Retrying does not help: the application has to obtain a new access token,
  #   which — now that personal access tokens expire — means walking a user
  #   through the OAuth flow again. A background job should discard rather than
  #   back off, and an application serving many merchants should flag the
  #   merchant whose token died instead of retrying on their behalf.
  #
  # @example Discarding rather than retrying a job whose credentials died
  #   class SynchronizationJob < ApplicationJob
  #     discard_on FulfilApi::UnauthorizedError
  #     retry_on FulfilApi::Error, wait: :polynomially_longer
  #   end
  #
  # A `403` deliberately does not raise this. Fulfil answers `403` both for a
  #   token that lacks a scope and for an action its business rules refuse, and
  #   telling a merchant to reconnect a working token is worse than surfacing the
  #   generic {FulfilApi::Error}.
  class UnauthorizedError < Error; end
end
