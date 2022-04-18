class BridgeApiItem < ApplicationRecord
  belongs_to :user
  has_many :bridge_api_accounts, dependent: :destroy

  def bank_name
    bank['name']
  end

  def logo_url
    bank['logo_url']
  end

  def status
    myself['status']
  end

  def status_code_info
    myself['status_code_info']
  end

  def status_code_description
    myself['status_code_description']
  end

  private

  def myself
    client = BridgeApi::Dependencies.resolve(:client)
    @myself ||= client.item(id: item_id, token: user.valid_access_token)
  end

  def bank
    client = BridgeApi::Dependencies.resolve(:client)
    @bank ||= client.bank(myself['bank_id'])
  end
end
