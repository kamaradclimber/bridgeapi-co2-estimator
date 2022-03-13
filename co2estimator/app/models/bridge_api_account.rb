class BridgeApiAccount < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy

  def refresh_transactions(event_timestamp_in_ms)
    client = BridgeApi::Dependencies.resolve(:client)
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
    identifying_hash = {
      bridgeapi_transaction_id: transaction_hash['id'], # we should put a DB index on this field
      description: transaction_hash['clean_description'],
      full_description: transaction_hash['bank_description'],
      amount: transaction_hash['amount'],
      currency_code: transaction_hash['currency_code'],
      date: Date.parse(transaction_hash['date']), # we should put a DB index on this field
      category_id: transaction_hash['category_id'],
      original_hash: transaction_hash.to_json
    }
    transaction = transactions.find_or_initialize_by(identifying_hash)
    matching_classes = Transaction.child_classes.select do |klass|
      # puts "Testing #{klass}"

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
      transaction = matching.new(identifying_hash)
      transactions << transaction
    end
    transaction
  end
end
