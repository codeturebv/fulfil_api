# frozen_string_literal: true

# Scopes the OAuth flow to a tenant the way a multi-merchant application does:
#   the tenant is picked when the flow starts and remembered in the session, as
#   Fulfil's callback carries nothing that identifies it.
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :remember_shop

  private

  def current_shop
    Shop.find_by(id: session[:shop_id])
  end

  def fulfil_installation_owner
    current_shop
  end

  def fulfil_merchant_id
    current_shop ? current_shop.fulfil_merchant_id : FulfilApi.configuration.merchant_id
  end

  def remember_shop
    session[:shop_id] = params[:shop_id] if params[:shop_id].present?
  end
end
