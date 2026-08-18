# The `fulfil_api` Ruby gem

The `fulfil_api` is a simple, powerful HTTP client written in Ruby to interact with Fulfil's API. It takes learnings from many years of working with Fulfil's APIs and turns it into an easy to use HTTP client.

## Installation

Install the gem and add to the application's Gemfile by executing:

```shell
  $ bundle add fulfil_api
```

If bundler is not being used to manage dependencies, install the gem by executing:

```shell
  $ gem install fulfil_api
```

## Usage

### Configuration

There are two ways of configuring the HTTP client:

1. Staticly through an initializer file (typically used in a Rails application)
2. Dynamically through calling the `FulfilApi.with_config` method.

The configuration of the FulfilApi client is thread-safe and therefore you can even combine both the static and dynamic configuration of Fulfil in case you need to.

#### Using a Static Configuration

```ruby
# config/initializers/fulfil_api.rb

FulfilApi.configure do |config|
  config.access_token = FulfilApi::AccessToken.new(ENV["FULFIL_API_KEY"])
  config.merchant_id = "the-id-of-the-merchant"
end
```


#### Using a Dynamic Configuration

`with_config` temporarily applies options **on top of the currently active configuration** (per thread) and reverts when the block returns. The options you pass are merged over the active config, so you only need to specify what changes — credentials and other settings are inherited rather than reset to their defaults.

```ruby
FulfilApi.with_config(
  access_token: FulfilApi::AccessToken.new(ENV["FULFIL_API_KEY"]),
  merchant_id: "the-id-of-the-merchant"
) do
  # Query the Fulfil API
end
```

This makes it easy to use different settings in contexts with different constraints. For example, a web request bound by a 30s timeout can keep tight defaults globally, while a background job (which has more time) overrides just the timeouts and retries without re-passing credentials:

```ruby
FulfilApi.with_config(
  request_options: { open_timeout: 5, read_timeout: 60, write_timeout: 30 },
  connection_options: { max_retries: 3, idle_timeout: 10 }
) do
  # Long-running work against the Fulfil API
end
```

#### Available Configuration Options

The following configuration options are (currently) available throught both configuration methods:

- `access_token` (`FulfilApi::AccessToken`): The `access_token` is required to authenticate with Fulfil's API endpoints. Fulfil supports two types of access tokens: "OAuth" and "Personal" access tokens. The gem supports both tokens and defaults to the personal access token.

> **NOTE:** To use an OAuth access token, use `FulfilApi::AccessToken.new(oauth_token, type: :oauth)`. Typically, you would use the OAuth access token only when using the [dynamic configuration](#using-a-dynamic-configuration) mode of the gem.

- `merchant_id` (`String`): The `merchant_id` is the subdomain that the Fulfil instance is hosted on. This configuration option is required to be able to query Fulfil's API endpoints.

- `request_options` (`Hash`): The `request_options` are the per-request timeout options for the HTTP client. See [https://lostisland.github.io/faraday/#/customization/request-options](https://lostisland.github.io/faraday/#/customization/request-options) in `faraday`.

> **NOTE:** With the persistent (keep-alive) adapter there is no single whole-request `timeout`; Faraday resolves `read_timeout`, `open_timeout`, and `write_timeout` independently. `read_timeout` is the value that governs a slow or stalled response.

- `connection_options` (`Hash`): Tuning for the persistent (keep-alive) connection. Supported keys:
  - `max_retries` (default `1`): Re-enables Ruby's built-in retry for **idempotent** requests (`GET`/`HEAD`/`PUT`/`DELETE`/`OPTIONS`). The `net_http_persistent` adapter disables this by forcing it to `0`, which makes a keep-alive socket the server has already dropped surface as a read timeout instead of being retried transparently on a fresh socket. `POST` is never auto-retried, so this is side-effect safe. Set to `0` to restore the adapter's default behaviour.
  - `idle_timeout` (`Integer`, optional): Seconds a pooled socket may sit idle before it is recycled. Lower this towards your server's keep-alive window to shrink the stale-socket window for non-idempotent requests.
  - `pool_size` (`Integer`, optional): Maximum number of concurrent connections kept in the pool.

> **NOTE:** When retries are enabled, the worst-case time for a request is roughly `(max_retries + 1) × read_timeout`. On platforms with a hard request cap (e.g. Heroku's 30s router limit), keep `read_timeout` low enough that this product stays under the cap.

### Querying the Fulfil API

> **NOTE:** Currently, the gem is under heavy development. The querying interface of the gem is really basic at the moment. In the future, we will closer match the querying interface of `ActiveRecord`.

The gem uses an `ActiveRecord` like query interface to query the Fulfil API.

```ruby
# Find one specific resource
sales_order = FulfilApi::Resource.set(model_name: "sale.sale").find_by(["id", "=", 100])
p sales_order["id"] # => 100

# Find a list of resources
sales_orders = FulfilApi::Resource.set(model_name: "sale.sale").where(["channel", "=", 4])
p sales_orders.size # => 500 (standard number of resources returned by Fulfil)
p sales_orders.first["id"] # => 10 (an example of an ID returned by Fulfil)

# Find a limited list of resources
sales_orders = FulfilApi::Resource.set(model_name: "sale.sale").where(["channel", "=", 4]).limit(50)
p sales_orders.size # => 50

# Include more resource details than the ID only
sales_orders = FulfilApi::Resource.set(model_name: "sale.sale").select("reference").where(["channel", "=", 4])
p sales_orders.first["reference"] # => SO1234

# Fetch nested data from a relation
line_items = FulfilApi::Resource.set(model_name: "sale.line").select("sale.reference")
p line_items.first["sale"]["reference"] # => SO1234

# Query nested data from a relation
line_items = FulfilApi::Resource.set(model_name: "sale.line").where(["sale.reference", "=", "SO1234"])
p line_items.first["id"] # => 10
```

> **NOTE:** It's important to note that the results from the Fulfil API are cached. This prevents you from accidentally overasking the Fulfil API. To reload the resources from the Fulfil API after you've already fetchted them, use the `.reload` on the returned relation (e.g. `line_items.reload`).

### Interacting with the `FulfilApi::Resource`

Any data returned through the `FulfilApi` gem returns a list or a single `FulfilApi::Resource`. The data of the API resource is accessible through a `Hash`-like method.

```ruby
sales_order = FulfilApi::Resource.set(model_name: "sale.sale").find_by(["id", "=", 100])
p sales_order["id"] # => 100
```

When you're requesting relational data for an API resource, you can access it in a similar manner.

```ruby
sales_order = FulfilApi::Resource.set(model_name: "sale.sale").select("channel.name").find_by(["id", "=", 100])
p sales_order["channel"]["name"] # => Shopify
```

> **NOTE:** Fulfil is not able to return nested data from `Array`-like API resources. If you want to find all line items of a sales order, it's typically better to query the line item resource directly.

```ruby
# You can't do this
FulfilApi::Resource.set(model_name: "sale.sale").select("lines.reference").find_by(["id", "=", 100])

# You can do this (BUT it's not recommended)
sales_order = FulfilApi::Resource.set(model_name: "sale.sale").select("lines").find_by(["id", "=", 100])
line_items = FulfilApi::Resource.set(model_name: "sale.line").where(["id", "in", sales_order["lines"]])

# You can do this (recommended)
line_items = FulfilApi::Resource.set(model_name: "sale.line").find_by(["sale.id", "=", 100])
```

### Handling Errors

Whenever a request to Fulfil fails, the gem raises a `FulfilApi::HttpError`. Every HTTP status code has its own subclass, named after the status code it represents, so you can rescue the exact failure you care about:

```ruby
begin
  FulfilApi::Resource.set(model_name: "sale.sale").find_by(["id", "=", 100])
rescue FulfilApi::HttpError::TooManyRequests => exception
  puts exception.message    # => "This user has exceeded an allotted request count. Try again later."
  puts exception.status_code # => 429

  sleep exception.response_headers["retry-after"].to_i
  retry
end
```

The message is the description reported by Fulfil. The raw response is available through `#response_body`, `#response_headers` and `#status_code`.

To catch anything that went wrong, rescue the base class instead:

```ruby
rescue FulfilApi::HttpError => exception
  Rails.logger.error("Fulfil responded with #{exception.status_code}: #{exception.message}")
```

A request that never reached Fulfil — a connection reset, a DNS failure, a timeout — has no status code to name and raises a `FulfilApi::HttpError` itself.

`FulfilApi::HttpError` inherits from `FulfilApi::Error`, the base class of every error in this gem, so code that already rescues `FulfilApi::Error` keeps working unchanged.

### Subscribing to Errors

Rescuing tells you about the one call you wrapped. To report *every* failure of the Fulfil API — to count rate limit hits in your APM, to page on authentication failures, to log what Fulfil actually said — subscribe once instead.

Every `FulfilApi::Error` publishes an `ActiveSupport::Notifications` event named `error.fulfil_api` when it is raised. `FulfilApi.on_error` is the shorthand for listening to it:

```ruby
# config/initializers/fulfil_api.rb

FulfilApi.on_error do |error|
  Appsignal.increment_counter("fulfil_api_errors", 1, error: error.class.name)
end
```

Because every error carries its own class, you can report only the failures you care about:

```ruby
FulfilApi.on_error do |error|
  next unless error.is_a?(FulfilApi::HttpError::TooManyRequests)

  Appsignal.increment_counter("fulfil_api_rate_limit_exceeded")
end
```

Subscribing through `ActiveSupport::Notifications` directly gives you the full payload, which carries the HTTP details of a `FulfilApi::HttpError` as separate keys — handy as metric dimensions:

```ruby
ActiveSupport::Notifications.subscribe(FulfilApi::Error::EVENT_NAME) do |event|
  event.payload[:exception]        # => ["FulfilApi::HttpError::TooManyRequests", "Try again later."]
  event.payload[:exception_object] # => the FulfilApi::HttpError::TooManyRequests instance
  event.payload[:status_code]      # => 429
  event.payload[:response_headers] # => { "retry-after" => "5", ... }
  event.payload[:response_body]    # => the raw response of Fulfil
end
```

Both methods return the subscriber, so you can stop listening again with `ActiveSupport::Notifications.unsubscribe(subscriber)`.

A few things worth knowing:

- The event is published when an error is **raised**, not when it is built. Rescuing it afterwards does not suppress the notification, and retrying a request publishes one event per attempt — which is exactly what you want when counting rate limit hits.
- The subscriber runs on the thread that raised the error, while the error travels up the stack. Keep it cheap and hand anything slow to a background job.
- A subscriber cannot change the behaviour of your application. If it raises, the exception is swallowed and reported on `$stderr` rather than replacing the `FulfilApi::Error` on its way up.

### Using the 3PL (TPL) Client

The gem also includes a client for Fulfil's [3PL Integration API](https://fulfil-3pl-integration-api.readme.io/reference/getting-started-with-your-api). This is a separate API that allows third-party logistics providers to interact with Fulfil on behalf of a merchant.

#### Configuration

Configure the 3PL client through the `tpl` option in the configuration block:

```ruby
FulfilApi.configure do |config|
  config.merchant_id = "the-id-of-the-merchant"

  config.tpl = {
    auth_token: ENV["FULFIL_3PL_AUTH_TOKEN"], # required
    merchant_id: "a-different-merchant-id",   # optional, falls back to config.merchant_id
    api_version: "v1"                         # optional, defaults to "v1"
  }
end
```

#### Making Requests

The 3PL client is accessible via `FulfilApi.tpl_client` and supports the standard HTTP methods:

```ruby
# GET request with optional URL parameters
FulfilApi.tpl_client.get("inbound-transfers", page: 1, per_page: 25)

# POST request with a request body
FulfilApi.tpl_client.post("inbound-transfers/receive.json", { tracking_number: "ABC123" })

# PUT request with a request body
FulfilApi.tpl_client.put("inbound-transfers/receive.json", { status: "received" })

# PATCH request with a request body
FulfilApi.tpl_client.patch("inbound-transfers/receive.json", { status: "received" })

```

> **NOTE:** For the full list of available 3PL API endpoints, refer to the [Fulfil 3PL Integration API documentation](https://fulfil-3pl-integration-api.readme.io/reference/getting-started-with-your-api).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bin/rake install`.

## Releasing

To release a new version, run the `bin/release` script. This will update the version number in `version.rb`, create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codeturebv/fulfil_api. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/codeturebv/fulfil_api/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Fulfil project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/codeturebv/fulfil_api/blob/main/CODE_OF_CONDUCT.md).
