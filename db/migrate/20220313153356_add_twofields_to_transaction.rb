class AddTwofieldsToTransaction < ActiveRecord::Migration[7.0]
  def change
    add_column :transactions, :bridgeapi_transaction_id, :integer
    add_column :transactions, :account_id, :integer
  end
end
