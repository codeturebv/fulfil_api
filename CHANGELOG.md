## [Unreleased]

- Publish an `ActiveSupport::Notifications` event named `error.fulfil_api` whenever a `FulfilApi::Error` is raised, so an application can report failures of the Fulfil API to its APM without rescuing every call into the gem. Subscribe with `FulfilApi.on_error { |error| ... }`, or through `ActiveSupport::Notifications` directly to also reach the status code, response body and response headers of a `FulfilApi::HttpError`.

- Raise a `FulfilApi::HttpError` instead of a generic `FulfilApi::Error` when a request to Fulfil fails, with a dedicated subclass per HTTP status code (e.g. `FulfilApi::HttpError::TooManyRequests` for a 429). The exception message is now the description reported by Fulfil rather than its serialized response body, and the status code, body and headers are available through `#status_code`, `#response_body` and `#response_headers`. `FulfilApi::HttpError` inherits from `FulfilApi::Error`, so existing rescues keep working.

- Re-enable Ruby's built-in retry for idempotent requests on the persistent connection, which the `net_http_persistent` adapter disables by forcing `max_retries` to `0`. This recovers stale keep-alive sockets transparently instead of surfacing them as read timeouts.
- Add a `connection_options` configuration option to tune the persistent connection (`max_retries`, `idle_timeout`, `pool_size`).
- `FulfilApi.with_config` now merges the temporary options over the active configuration instead of replacing it, so a block inherits credentials and other unspecified settings rather than resetting them to their defaults.

## [0.1.0] - 2024-08-10

- Initial release
