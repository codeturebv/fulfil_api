# frozen_string_literal: true

# Stands in for a tenant that brings its own Fulfil workspace, the way Packwork
#   keeps one installation per Shopify store.
class Shop < ActiveRecord::Base
  include FulfilApi::Installable
end
