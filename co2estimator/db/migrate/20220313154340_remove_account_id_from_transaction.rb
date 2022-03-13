class RemoveAccountIdFromTransaction < ActiveRecord::Migration[7.0]
  def change
    remove_column :transactions, :account_id, :string
  end
end
