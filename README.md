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

- `oauth` (`FulfilApi::OAuth::Configuration`): The credentials and options of the OAuth app used by the [OAuth flow](#authenticating-with-oauth-rails). Assign it a `Hash`, or set its options one by one on `config.oauth`.

### Authenticating with OAuth (Rails)

Fulfil caps the lifetime of personal access tokens, so an application that has to keep working unattended needs an OAuth token instead. The gem ships the whole flow as a Rails engine: a user is sent to Fulfil's consent screen, comes back with an authorization code, and the resulting token is stored as a `FulfilApi::Installation`.

The Rails parts of the gem only load when the gem is used from within a Rails application. Everywhere else, `fulfil_api` stays the plain HTTP client it has always been.

#### Setting it up

1. Create an app in Fulfil's [authentication dashboard](https://auth.fulfil.io/user/clients) and whitelist `https://your-app.example.com/fulfil/callback` as a redirection URL.
2. Run the install generator and its migration:

```shell
  $ bin/rails generate fulfil_api:install
  $ bin/rails db:migrate
```

The generator writes `config/initializers/fulfil_api.rb`, adds the migration for the `fulfil_api_installations` table, and mounts the engine at `/fulfil`.

3. Fill in the app's credentials:

```ruby
# config/initializers/fulfil_api.rb

FulfilApi.configure do |config|
  config.merchant_id = ENV.fetch("FULFIL_MERCHANT_ID", nil)

  config.oauth.client_id = ENV.fetch("FULFIL_OAUTH_CLIENT_ID", nil)
  config.oauth.client_secret = ENV.fetch("FULFIL_OAUTH_CLIENT_SECRET", nil)
  config.oauth.scopes = %w[sale.sale]
end
```

> **NOTE:** The access tokens are encrypted at rest with Active Record Encryption. Run `bin/rails db:encryption:init` and store the keys in your credentials if the application does not use it yet.

#### Available OAuth options

- `client_id` / `client_secret` (`String`): The app's credentials, found under **App Credentials** in Fulfil's authentication dashboard.
- `scopes` (`Array<String>`, default `[]`): The scopes to request. See [https://developers.fulfil.io](https://developers.fulfil.io) for the full list.
- `access_type` (`Symbol`, default `:offline_access`): `:offline_access` grants a permanent token that keeps working when no user is around, which is what background jobs need. `:user_session` grants a token that expires with the user's Fulfil session. Fulfil has no refresh token, so an expired `:user_session` token can only be replaced by walking through the flow again.
- `after_install_path` (`String` or callable, default `"/"`): Where the user ends up after installing the app, unless they were sent to the flow from somewhere else. A callable receives the `FulfilApi::Installation` that was created.
- `parent_controller` (`String`, default `"ApplicationController"`): The controller the engine's own controllers inherit from, so the flow picks up the application's layout, authentication, and multi-tenancy.
- `redirect_uri` (`String`, optional): Defaults to the engine's callback URL, derived from the incoming request. Set it when the application sits behind a proxy that rewrites the host.

#### Kicking off the flow automatically

Include `FulfilApi::Authenticated` in a controller. Every action then runs with a client authenticated as the current installation, and a user without a usable token is sent through the flow and returned to where they were headed.

```ruby
class SalesOrdersController < ApplicationController
  include FulfilApi::Authenticated

  def index
    @sales_orders = FulfilApi::Resource.set(model_name: "sale.sale").limit(50)
  end
end
```

#### One installation per tenant

By default the installation belongs to the application as a whole, which is what an application built for a single merchant needs. An application serving many merchants ties the installation to a record instead:

```ruby
class Shop < ApplicationRecord
  include FulfilApi::Installable
end
```

Point the flow at the current tenant by overriding two methods in `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  private

  def fulfil_installation_owner
    Current.shop
  end

  def fulfil_merchant_id
    Current.shop.fulfil_merchant_id
  end
end
```

Outside of a request — in a background job, for instance — go through the record:

```ruby
shop.with_fulfil_config do |client|
  client.get("model/sale.sale")
end
```

`FulfilApi::Installation` is a plain Active Record model, so an application-wide token works the same way:

```ruby
FulfilApi::Installation.global.sole.with_config do |client|
  client.get("model/sale.sale")
end
```

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
