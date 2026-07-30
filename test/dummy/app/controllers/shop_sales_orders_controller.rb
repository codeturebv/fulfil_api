# frozen_string_literal: true

# Scopes the installation to a tenant, the way a multi-merchant application does.
class ShopSalesOrdersController < ApplicationController
  include FulfilApi::Authenticated

  def index
    render plain: FulfilApi.configuration.merchant_id
  end

  private

  def current_shop
    @current_shop ||= Shop.find(params[:shop_id])
  end

  def fulfil_installation_owner
    current_shop
  end

  def fulfil_merchant_id
    current_shop.fulfil_merchant_id
  end
end
