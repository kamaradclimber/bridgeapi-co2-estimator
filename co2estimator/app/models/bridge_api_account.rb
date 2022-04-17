class BridgeApiAccount < ApplicationRecord
  belongs_to :bridge_api_item
  has_many :transactions, dependent: :destroy

  def refresh_transactions(event_timestamp_in_ms)
    client = BridgeApi::Dependencies.resolve(:client)
    user = bridge_api_item.user
    updated = client.updated_transactions(since: last_successful_fetch, account_id: id, token: user.valid_access_token).to_a
    puts "Detected #{updated.size} transactions for account #{id} of user #{user.username}"
    updated.each do |transaction_hash|
      puts transaction_hash
      transaction = build_transaction(transaction_hash)
      puts "will save this transaction: #{transaction}"
      transaction.save!
    end
    # we don't know how to be sure when records has been updated before updates was sent, so we substract 1h to avoid loosing updates
    self.last_successful_fetch = Time.at(event_timestamp_in_ms / 1000.0) - 3600
    save
  end

  def build_transaction(transaction_hash)
    transaction = transactions.find_or_initialize_by(bridgeapi_transaction_id: transaction_hash['id'])
    transaction.description = transaction_hash['clean_description']
    transaction.full_description = transaction_hash['bank_description']
    transaction.amount = transaction_hash['amount']
    transaction.currency_code = transaction_hash['currency_code']
    transaction.date = Date.parse(transaction_hash['date'])
    transaction.category_id = transaction_hash['category_id']
    transaction.original_hash = transaction_hash.to_json
    matching_classes = Transaction.child_classes.select do |klass|
      klass.match?(transaction)
    rescue NotImplementedError
      false
    end
    matching = matching_classes.min do |k1, k2|
      if k1 < k2
        -1
      elsif k2 < k1
        1
      else
        0
      end
    end
    puts "Found #{matching_classes.size} classes matching #{transaction.short_s}, selecting #{matching} as the most precise"
    if matching
      transaction.type = matching
      transactions << transaction
      transaction.save!
      # reload the transaction to get the correct class
      # we can probably avoid the write-then-read pattern but it's quite convenient for now
      transaction = transactions.find_or_initialize_by(bridgeapi_transaction_id: transaction_hash['id'])
    end
    transaction
  end
end
