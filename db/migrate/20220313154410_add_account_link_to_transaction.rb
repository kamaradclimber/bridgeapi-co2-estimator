class AddAccountLinkToTransaction < ActiveRecord::Migration[7.0]
  def change
    add_reference :transactions, :bridge_api_account, null: false, foreign_key: true
  end
end
