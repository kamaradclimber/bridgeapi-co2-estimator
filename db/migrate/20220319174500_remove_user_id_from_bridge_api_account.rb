class RemoveUserIdFromBridgeApiAccount < ActiveRecord::Migration[7.0]
  def change
    remove_column :bridge_api_accounts, :user_id, :integer
  end
end
