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

### TODO: Querying the Fulfil API

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
