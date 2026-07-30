## [Unreleased]

- Add support for Fulfil's OAuth 2.0 authorization flow, so applications no longer depend on personal access tokens now that Fulfil caps their lifetime. `FulfilApi::OAuth::Authorization` builds the consent screen URL and exchanges the authorization code for a token, and `config.oauth` holds the OAuth app's credentials.
- Ship the flow as a Rails engine that is only loaded inside a Rails application. `bin/rails generate fulfil_api:install` writes the initializer, adds the migration for `FulfilApi::Installation`, and mounts the engine. Installing changes nothing about how an application behaves until `config.oauth.parent_controller` names the controller the flow runs under, so an application still on personal access tokens can move to OAuth in its own time. There is no default: the engine's controllers inherit from it, and guessing wrong leaves an endpoint a stranger can use to record their own Fulfil workspace over the application's.
- Add the `FulfilApi::Authenticated` controller concern, which runs every action with a client authenticated as the current installation and sends a user without a usable token through the OAuth flow.
- Raise `FulfilApi::UnauthorizedError` when Fulfil rejects the credentials a request was made with, so an application can tell a dead access token apart from everything else that can go wrong and stop retrying it. It subclasses `FulfilApi::Error`, so existing rescues keep working. A `403` deliberately keeps raising the generic error, because Fulfil uses it both for a missing scope and for an action its business rules refuse.
- Add the `FulfilApi::Installable` model concern, so an application serving many merchants can keep one installation per record instead of one for the whole application. A record is connected to a single Fulfil workspace.

- Re-enable Ruby's built-in retry for idempotent requests on the persistent connection, which the `net_http_persistent` adapter disables by forcing `max_retries` to `0`. This recovers stale keep-alive sockets transparently instead of surfacing them as read timeouts.
- Add a `connection_options` configuration option to tune the persistent connection (`max_retries`, `idle_timeout`, `pool_size`).
- `FulfilApi.with_config` now merges the temporary options over the active configuration instead of replacing it, so a block inherits credentials and other unspecified settings rather than resetting them to their defaults.

## [0.1.0] - 2024-08-10

- Initial release
