# frozen_string_literal: true

ActiveRecord::Schema[7.2].define(version: 1) do
  create_table :fulfil_api_installations, force: true do |t|
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

  add_index :fulfil_api_installations, %i[owner_type owner_id merchant_id],
            name: "index_fulfil_api_installations_on_owner_and_merchant", unique: true

  create_table :shops, force: true do |t|
    t.string :name
    t.string :fulfil_merchant_id

    t.timestamps
  end
end
