# frozen_string_literal: true

require_relative "lib/fulfil_api/version"

Gem::Specification.new do |spec|
  spec.name = "fulfil_api"
  spec.version = FulfilApi::VERSION
  spec.authors = ["Stefan Vermaas"]
  spec.email = ["stefan@codeture.nl"]

  spec.summary = "A HTTP client to interact the Fulfil.io API"
  spec.description = "A Ruby HTTP client to interact with the API endpoints of Fulfil.io"
  spec.homepage = "https://www.github.com/codeturebv/fulfil_api"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://www.github.com/codeturebv/fulfil_api"
  spec.metadata["changelog_uri"] = "https://www.github.com/codeturebv/fulfil_api/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", "~> 7.2" # A toolkit of support libraries and Ruby core extensions extracted from the Rails framework. [https://github.com/rails/rails/tree/main/activesupport]
  spec.add_dependency "faraday", "~> 2.10" # A HTTP/REST API client library. [https://github.com/lostisland/faraday]
  spec.add_dependency "faraday-net_http_persistent", "~> 2.0" # Faraday Adapter for NetHttpPersistent. [https://github.com/lostisland/faraday-net_http_persistent]
  spec.add_dependency "zeitwerk", "~> 2.6" # Zeitwerk implements constant autoloading with Ruby semantics. [https://github.com/fxn/zeitwerk]

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
