class CreateBridgeApiAccessTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :bridge_api_access_tokens do |t|
      t.string :username
      t.string :password
      t.datetime :expires_at
      t.string :value

      t.timestamps
    end
  end
end
