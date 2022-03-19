require 'bridgeapi/client'

class User < ApplicationRecord
  has_many :bridge_api_items, dependent: :destroy
  has_many :bridge_api_access_tokens, dependent: :destroy

  has_many :bridge_api_accounts, through: :bridge_api_items

  validates :username, presence: true, uniqueness: true
  validates_format_of :username, with: URI::MailTo::EMAIL_REGEXP
  validates :bridgeapi_password, presence: true, length: { minimum: 10 }
  validates :bridgeapi_uuid, presence: true, length: { minimum: 10 }

  def valid_access_token
    my_tokens = bridge_api_access_tokens
    if my_tokens.any?
      my_tokens.first.refreshed_value
      return my_tokens.first
    end

    token = BridgeApiAccessToken.new(username: username, password: bridgeapi_password, user: self)
    token.refresh!
    raise 'Impossible to save access token' unless token.save

    token
  end

  def items
    client = BridgeApi::Dependencies.resolve(:client)
    my_items = client.items(token: valid_access_token).to_a
    my_items.each do |item|
      bank = client.bank(item['bank_id'])
      item['bank_name'] = bank['name']
      item['logo_url'] = bank['logo_url']
    end
    my_items
  end

  # @return [Hash] with a redirect_url key
  def connect_new_bridgeapi_item
    client = BridgeApi::Dependencies.resolve(:client)
    client.connect_new_account(token: valid_access_token)
  end

  def all_transactions(since)
    bridge_api_items.flat_map(&:bridge_api_accounts).flat_map(&:transactions).sort_by(&:date).select { |t| t.date >= since }
  end

  def report(transactions)
    lines = []
    total_co2_kg = 0
    transactions.each do |transaction|
      total_co2_kg += transaction.co2_kg || 0
    end

    lines << "Estimated CO2 footprint: #{total_co2_kg.round(0)}kg"

    accounted_euros = transactions.reject { |t| t.instance_of?(Transaction) }.map { |t| t.amount.abs }.sum
    total = transactions.map { |t| t.amount.abs }.sum
    total = 1 if total.zero?

    lines << "This method accounts for #{(accounted_euros / total * 100).round(0)}% of expenses"

    largest_without_estimation = transactions.select { |t| t.instance_of?(Transaction) }.max_by { |t| t.amount.abs }
    lines << "Largest transaction without impact estimation: #{largest_without_estimation}"
    lines
  end
end
