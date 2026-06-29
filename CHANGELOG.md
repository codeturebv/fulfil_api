## [Unreleased]

- Re-enable Ruby's built-in retry for idempotent requests on the persistent connection, which the `net_http_persistent` adapter disables by forcing `max_retries` to `0`. This recovers stale keep-alive sockets transparently instead of surfacing them as read timeouts.
- Add a `connection_options` configuration option to tune the persistent connection (`max_retries`, `idle_timeout`, `pool_size`).

## [0.1.0] - 2024-08-10

- Initial release
