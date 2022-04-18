class CreateBridgeApiItems < ActiveRecord::Migration[7.0]
  def change
    create_table :bridge_api_items do |t|
      t.integer :item_id
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
