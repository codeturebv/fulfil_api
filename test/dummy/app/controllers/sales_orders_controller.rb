# frozen_string_literal: true

# Uses the application-wide installation.
class SalesOrdersController < ApplicationController
  include FulfilApi::Authenticated

  def index
    render plain: FulfilApi.configuration.access_token.value
  end
end
