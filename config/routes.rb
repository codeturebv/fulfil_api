# frozen_string_literal: true

FulfilApi::Engine.routes.draw do
  resource :installation, only: %i[new]

  # Fulfil sends the user back with a `GET`, so the installation cannot be
  #   created through the resourceful `POST /installation` route.
  get "callback", to: "installations#create", as: :callback
end
