# frozen_string_literal: true

class CreateFulfilApiInstallations < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :fulfil_api_installations do |t|
      # An installation without an owner is the application-wide installation.
      t.references :owner, polymorphic: true, null: true, index: false

      t.string :merchant_id, null: false

      t.text :access_token
      t.text :offline_access_token
      t.string :token_type
      t.text :scopes
      t.datetime :expires_at

      t.integer :associated_user_id
      t.string :associated_user_email
      t.string :associated_user_name

      t.timestamps
    end

    # Databases treat NULLs as distinct, so this index does not constrain the
    #   application-wide installation. FulfilApi::Installation validates the
    #   uniqueness of the merchant for that case.
    add_index :fulfil_api_installations, %i[owner_type owner_id merchant_id],
              name: "index_fulfil_api_installations_on_owner_and_merchant", unique: true
  end
end
