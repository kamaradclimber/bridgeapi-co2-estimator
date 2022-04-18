class BridgeApiAccount < ApplicationRecord
  belongs_to :bridge_api_item
  has_many :transactions, dependent: :destroy
  delegate :user, to: :bridge_api_item

  def refresh_transactions(event_timestamp_in_ms)
    client = BridgeApi::Dependencies.resolve(:client)
    user = bridge_api_item.user
    updated = client.updated_transactions(since: last_successful_fetch, account_id: id, token: user.valid_access_token).to_a
    puts "Detected #{updated.size} transactions for account #{id} of user #{user.username}"
    updated.each do |transaction_hash|
      transaction = transactions.find_or_initialize_by(bridgeapi_transaction_id: transaction_hash['id'])
      if transaction.user_updated?
        puts 'Transaction was updated manually by user, will not overwrite modifications'
        transaction.original_hash = transaction_hash.to_json
      else
        transaction.hydrate_from(transaction_hash)
        transaction.refresh_subclass
        transaction.save!
      end
    end
    # we don't know how to be sure when records has been updated before updates was sent, so we substract 1h to avoid loosing updates
    self.last_successful_fetch = Time.at(event_timestamp_in_ms / 1000.0) - 3600
    save
  end
end
