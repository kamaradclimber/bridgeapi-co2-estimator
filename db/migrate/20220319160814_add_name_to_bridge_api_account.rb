class AddNameToBridgeApiAccount < ActiveRecord::Migration[7.0]
  def change
    add_column :bridge_api_accounts, :name, :string
  end
end
