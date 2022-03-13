class AddUserReferenceToBridgeApiAccessToken < ActiveRecord::Migration[7.0]
  def change
    add_reference :bridge_api_access_tokens, :user, null: false, foreign_key: true
  end
end
