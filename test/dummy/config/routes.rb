# frozen_string_literal: true

Rails.application.routes.draw do
  mount FulfilApi::Engine => "/fulfil"

  resources :sales_orders, only: %i[index]
  resources :shop_sales_orders, only: %i[index]
end
