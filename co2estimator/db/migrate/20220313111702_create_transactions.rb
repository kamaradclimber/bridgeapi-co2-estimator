class CreateTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :transactions do |t|
      t.string :description
      t.string :full_description
      t.decimal :amount
      t.string :currency_code
      t.date :date
      t.integer :category_id
      t.text :original_hash

      t.timestamps
    end
  end
end
