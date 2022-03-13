class CreateBridgeApiAccounts < ActiveRecord::Migration[7.0]
  def change
    create_table :bridge_api_accounts do |t|
      t.datetime :last_successful_fetch
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
