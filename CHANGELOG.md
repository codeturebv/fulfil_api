## [Unreleased]

- Add support for Fulfil's OAuth 2.0 authorization flow, so applications no longer depend on personal access tokens now that Fulfil caps their lifetime. `FulfilApi::OAuth::Authorization` builds the consent screen URL and exchanges the authorization code for a token, and `config.oauth` holds the OAuth app's credentials.
- Ship the flow as a Rails engine that is only loaded inside a Rails application. `bin/rails generate fulfil_api:install` writes the initializer, adds the migration for `FulfilApi::Installation`, and mounts the engine. Installing changes nothing about how an application behaves until `config.oauth.parent_controller` names the controller the flow runs under, so an application still on personal access tokens can move to OAuth in its own time. There is no default: the engine's controllers inherit from it, and guessing wrong leaves an endpoint a stranger can use to record their own Fulfil workspace over the application's.
- Add the `FulfilApi::Authenticated` controller concern, which runs every action with a client authenticated as the current installation and sends a user without a usable token through the OAuth flow.
- Add the `FulfilApi::Installable` model concern, so an application serving many merchants can keep one installation per record instead of one for the whole application. A record is connected to a single Fulfil workspace.

- Add an optional circuit breaker, backed by [Faulty](https://github.com/ParentSquare/faulty), that stops sending requests to a Fulfil instance that keeps failing, so a struggling instance can't tie up every thread of an application that talks to several of them. Pass a `Faulty` instance as `circuit_breaker`; each Fulfil instance gets its own circuit, and while it's open requests raise a `FulfilApi::CircuitOpen` without touching the network.

- Retry only the requests that are safe to retry. Ruby's built-in retry treated every `PUT` as idempotent, but Fulfil writes through `PUT` too (updating a record, holding a shipment), so a write that timed out could be sent twice. Retries now run through `faraday-retry`, configured to only retry `GET` requests and `PUT` requests to `search_read` and `search_count` by default, configurable through the new `retry_options`. The built-in retry is off by default again; `connection_options: { max_retries: ... }` still turns it on.

- Expand a nested field into its relation even when the field carries the same name as the relation it hangs off. Selecting both `tracking_number` and `tracking_number.tracking_number` on a shipment used to drop the relation and leave the tracking number as a plain string on the shipment itself, because the gem decided where a field belonged by matching names in the path instead of counting positions.

- Publish an `ActiveSupport::Notifications` event named `error.fulfil_api` whenever a `FulfilApi::Error` is raised, so an application can report failures of the Fulfil API to its APM without rescuing every call into the gem. Subscribe with `FulfilApi.on_error { |error| ... }`, or through `ActiveSupport::Notifications` directly to also reach the status code, response body and response headers of a `FulfilApi::HttpError`.

- Raise a `FulfilApi::HttpError` instead of a generic `FulfilApi::Error` when a request to Fulfil fails, with a dedicated subclass per HTTP status code (e.g. `FulfilApi::HttpError::TooManyRequests` for a 429). The exception message is now the description reported by Fulfil rather than its serialized response body, and the status code, body and headers are available through `#status_code`, `#response_body` and `#response_headers`. `FulfilApi::HttpError` inherits from `FulfilApi::Error`, so existing rescues keep working.

- Re-enable Ruby's built-in retry for idempotent requests on the persistent connection, which the `net_http_persistent` adapter disables by forcing `max_retries` to `0`. This recovers stale keep-alive sockets transparently instead of surfacing them as read timeouts.
- Add a `connection_options` configuration option to tune the persistent connection (`max_retries`, `idle_timeout`, `pool_size`).
- `FulfilApi.with_config` now merges the temporary options over the active configuration instead of replacing it, so a block inherits credentials and other unspecified settings rather than resetting them to their defaults.

## [0.1.0] - 2024-08-10

- Initial release
