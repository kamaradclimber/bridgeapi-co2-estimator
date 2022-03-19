class AddBridgeApiItemToBridgeApiAccount < ActiveRecord::Migration[7.0]
  def change
    add_reference :bridge_api_accounts, :bridge_api_item, null: false, foreign_key: true
  end
end
