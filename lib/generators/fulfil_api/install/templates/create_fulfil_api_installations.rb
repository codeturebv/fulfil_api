# frozen_string_literal: true

class CreateFulfilApiInstallations < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :fulfil_api_installations do |t|
      # An installation without an owner is the application-wide installation.
      t.references :owner, polymorphic: true, null: true, index: false

      t.string :merchant_id, null: false

      # Fulfil grants the permanent token only in `offline_access` mode, and the
      #   short-lived one is the only token in `user_session` mode. Neither is
      #   required on its own; FulfilApi::Installation requires one of the two.
      t.text :access_token
      t.text :offline_access_token

      # The gem fills the token type in rather than relying on Fulfil to send it.
      t.string :token_type, null: false, default: "Bearer"

      # Nullable because Active Record serialization writes an empty list as
      #   NULL and reads it back as one, so the column is never meaningfully
      #   blank even though it can be NULL.
      t.text :scopes

      # Describes the short-lived token only. A permanent token has no expiry:
      #   it is revoked by uninstalling the app, not by time.
      t.datetime :expires_at

      # Who walked through the authorization flow. Recorded for support, nothing
      #   in the gem depends on it, and Fulfil is free to leave parts of it out.
      t.integer :associated_user_id
      t.string :associated_user_email
      t.string :associated_user_name

      t.timestamps
    end

    # An owner is connected to a single Fulfil workspace. Databases treat NULLs
    #   as distinct, so this index does not constrain the application-wide
    #   installation; FulfilApi::Installation validates that case.
    add_index :fulfil_api_installations, %i[owner_type owner_id], unique: true
  end
end
