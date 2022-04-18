class AddBridgeApiUuidToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :bridgeapi_uuid, :string
  end
end
