# frozen_string_literal: true

module Minitest
  class Test
    include FulfilApi::TestHelper

    # Restores the configuration the dummy application booted with, so a test
    #   that replaces or wipes it cannot leak into whichever test the randomized
    #   order puts next.
    #
    # @return [void]
    def before_setup
      super
      FulfilApi.configuration = FULFIL_API_BOOT_CONFIGURATION.dup
    end
  end
end
