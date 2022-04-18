class RemoveUserIdFromTransaction < ActiveRecord::Migration[7.0]
  def change
    remove_column :transactions, :user_id, :string
  end
end
