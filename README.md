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

```ruby
FulfilApi.with_config(
  access_token: FulfilApi::AccessToken.new(ENV["FULFIL_API_KEY"]),
  merchant_id: "the-id-of-the-merchant"
) do
  # Query the Fulfil API
end
```

#### Available Configuration Options

The following configuration options are (currently) available throught both configuration methods:

- `access_token` (`FulfilApi::AccessToken`): The `access_token` is required to authenticate with Fulfil's API endpoints. Fulfil supports two types of access tokens: "OAuth" and "Personal" access tokens. The gem supports both tokens and defaults to the personal access token.

> **NOTE:** To use an OAuth access token, use `FulfilApi::AccessToken.new(oauth_token, type: :oauth)`. Typically, you would use the OAuth access token only when using the [dynamic configuration](#using-a-dynamic-configuration) mode of the gem.

- `merchant_id` (`String`): The `merchant_id` is the subdomain that the Fulfil instance is hosted on. This configuration option is required to be able to query Fulfil's API endpoints.

- `request_options` (`Hash`): The `request_options` are the configuration options for the HTTP client. See [https://lostisland.github.io/faraday/#/customization/request-options](https://lostisland.github.io/faraday/#/customization/request-options) in `faraday`.

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
# GET request with optional query parameters
FulfilApi.tpl_client.get("shipments", page: 1, per_page: 25)

# POST request with a request body
FulfilApi.tpl_client.post("shipments", { tracking_number: "ABC123" })

# PUT request with a request body
FulfilApi.tpl_client.put("shipments/1", { status: "shipped" })

# PATCH request with a request body
FulfilApi.tpl_client.patch("shipments/1", { status: "delivered" })

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
