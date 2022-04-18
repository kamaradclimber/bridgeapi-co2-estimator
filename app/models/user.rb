require 'bridgeapi/client'

class User < ApplicationRecord
  has_many :bridge_api_items, dependent: :destroy
  has_many :bridge_api_access_tokens, dependent: :destroy

  has_many :bridge_api_accounts, through: :bridge_api_items

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates_format_of :email, with: URI::MailTo::EMAIL_REGEXP
  validates :bridgeapi_password, presence: true, length: { minimum: 10 }
  validates :bridgeapi_uuid, presence: true, length: { minimum: 10 }

  def valid_access_token
    my_tokens = bridge_api_access_tokens
    if my_tokens.any?
      my_tokens.first.refreshed_value
      return my_tokens.first
    end

    token = BridgeApiAccessToken.new(username: email, password: bridgeapi_password, user: self)
    token.refresh!
    raise 'Impossible to save access token' unless token.save

    token
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
    total_euros = transactions.map { |t| t.amount.abs }.sum
    total_euros = 1 if total_euros.zero?

    accounted_transactions = transactions.reject { |t| t.instance_of?(Transaction) }.count
    total_count = [transactions.count, 1].max

    lines << <<~MSG
      This method accounts for #{(accounted_transactions.to_f / total_count * 100).round(0)}% of expanses (and #{(accounted_euros / total_euros * 100).round(0)}% of total value)
    MSG

    largest_without_estimation = transactions.select { |t| t.instance_of?(Transaction) }.max_by { |t| t.amount.abs }
    lines << "Largest transaction without impact estimation: #{largest_without_estimation}"
    lines
  end
end
