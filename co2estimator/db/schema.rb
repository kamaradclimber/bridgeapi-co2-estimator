# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 20_220_313_173_020) do
  create_table 'bridge_api_access_tokens', force: :cascade do |t|
    t.string 'username'
    t.string 'password'
    t.datetime 'expires_at'
    t.string 'value'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.integer 'user_id', null: false
    t.index ['user_id'], name: 'index_bridge_api_access_tokens_on_user_id'
  end

  create_table 'bridge_api_accounts', force: :cascade do |t|
    t.datetime 'last_successful_fetch'
    t.integer 'user_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['user_id'], name: 'index_bridge_api_accounts_on_user_id'
  end

  create_table 'transactions', force: :cascade do |t|
    t.string 'description'
    t.string 'full_description'
    t.decimal 'amount'
    t.string 'currency_code'
    t.date 'date'
    t.integer 'category_id'
    t.text 'original_hash'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.integer 'bridgeapi_transaction_id'
    t.integer 'bridge_api_account_id', null: false
    t.string 'type'
    t.index ['bridge_api_account_id'], name: 'index_transactions_on_bridge_api_account_id'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'username'
    t.string 'bridgeapi_password'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'bridgeapi_uuid'
  end

  add_foreign_key 'bridge_api_access_tokens', 'users'
  add_foreign_key 'bridge_api_accounts', 'users'
  add_foreign_key 'transactions', 'bridge_api_accounts'
end
